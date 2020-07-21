# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id            :bigint           not null, primary key
#  email         :string(255)      default(""), not null
#  last_login_at :datetime
#  name          :string(255)      default(""), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#  index_users_on_name   (name) UNIQUE
#
require 'csv'

class User < ApplicationRecord
  BOM = "\uFEFF"
  TIME_FORMAT = '%F_%H_%M_%S_%L%Z'
  CSV_HEADERS = %w[id name last_login_at project_name].freeze
  CSV_DATETIME_FORMAT = '%F %H:%M:%S'
  UTC_OFFSET = '+09:00'

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name,  presence: true, uniqueness: { case_sensitive: true }

  has_many :project_user_relations
  has_many :projects, through: :project_user_relations

  def self.csv_name
    "#{Rails.root}/csvs/users_#{Time.zone.now.strftime(TIME_FORMAT)}.csv"
  end

  def self.to_csv_by_sql(opts = {})
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    raise "No suport the db dapter: #{adapter}" if adapter != "mysql2"

    users = User.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]
    select_sql = <<-SQL.squish
      users.id,
      users.name,
      CASE
        WHEN users.last_login_at IS NULL THEN '' 
        ELSE convert_tz(users.last_login_at, '+00:00','#{UTC_OFFSET}')
      END AS last_login_at,
      CASE
        WHEN projects.name IS NULL THEN '' ELSE projects.name
      END AS project_name
    SQL
    users = User.readonly
                .where(id: users.first.id..users.last.id)
                .left_joins(:projects)
                .select(select_sql)
                .order("users.id ASC, projects.id ASC")
    sql = <<-SQL.squish
      (SELECT 'id', 'name', 'last_login_at', 'project_name')
      UNION
      (#{users.to_sql})
      INTO OUTFILE ?
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';
    SQL
    sql = User.sanitize_sql([sql, csv_name])
    User.connection.execute(sql)
  end

  def self.to_csv(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }

    select_sql = <<-SQL.squish
      users.id, users.name, users.last_login_at, projects.name AS project_name
    SQL
    users = User.readonly.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]
    users = User.where(id: users.first.id..users.last.id)
                .left_joins(:projects)
                .select(select_sql)
                .order("users.id ASC, projects.id ASC")
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      users.in_batches.each_record do |row|
        last_login_at = row.last_login_at&.strftime(CSV_DATETIME_FORMAT)
        csv << [row.id, row.name, last_login_at, row.project_name]
      end
    end
  end

  # N+1 問題を含む実装
  def self.to_csv_x(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }

    users = User.readonly.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]

    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      users.in_batches.each_record do |row|
        project_names = row.projects.order(:id).map(&:name)
        last_login_at = row.last_login_at&.strftime(CSV_DATETIME_FORMAT)
        if !project_names.empty?
          project_names.each do |p_name|
            csv << [row.id, row.name, last_login_at, p_name]
          end
        else
          csv << [row.id, row.name, last_login_at, ""]
        end
      end
    end
  end

  def self.export(file_path, users = nil)
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    raise "No suport the db dapter: #{adapter}" if adapter != 'mysql2'

    users ||= User.order(:id).all
    select_sql =
      User.columns.map { |x| [x.name.to_s, x.type] }.map do |col|
        if col[1] == :datetime
          "CASE" \
          "  WHEN users.#{col[0]} IS NULL THEN ''" \
          "  ELSE convert_tz(users.#{col[0]}, '+00:00','#{UTC_OFFSET}') " \
          "END AS #{col[0]}"
        else
          "CASE" \
          "  WHEN users.#{col[0]} IS NULL THEN ''" \
          "  ELSE users.#{col[0]} " \
          "END AS #{col[0]}"
        end
      end.join(',')

    sql = <<-SQL.squish
      (SELECT '#{User.column_names.join('\',\'')}')
      UNION
      (SELECT #{select_sql} FROM users)
      INTO OUTFILE ?
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';
    SQL
    sql = User.sanitize_sql([sql, file_path])
    User.connection.execute(sql)
  end

  def self.import(file_path)
    the_time = Time.zone.now
    rows = []
    CSV.foreach(file_path, headers: true) do |row|
      row_hash = row.to_hash
      row_hash['created_at'] =
        if row_hash['created_at'].presence
          Time.zone.parse(row_hash['created_at'])
        else
          the_time
        end
      row_hash['updated_at'] =
        if row_hash['updated_at'].presence
          Time.zone.parse(row_hash['updated_at'])
        else
          the_time
        end
      row_hash['last_login_at'] =
        if row_hash['last_login_at'].presence
          Time.zone.parse(row_hash['last_login_at'])
        else
          nil
        end

      rows << row_hash
      if rows.size > 1000
        # User.upsert_all(rows)
        User.insert_all(rows)
        rows = []
      end
    end
    User.insert_all(rows) if rows.size.positive?
  end

  def self.import_x(file_path)
    CSV.foreach(file_path, headers: true) do |row|
      User.find_or_create_by(row.to_hash)
    end
  end
end
