# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  email      :string(255)      default(""), not null
#  name       :string(255)      default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
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
  CSV_HEADERS = %w[id name project_name].freeze

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
        WHEN projects.name IS NULL THEN '' ELSE projects.name
      END AS project_name
    SQL
    users = User.readonly
                .where(id: users.first.id..users.last.id)
                .left_joins(:projects)
                .select(select_sql)
                .order("users.id ASC, projects.id ASC")
    sql = <<-SQL.squish
      (SELECT 'id', 'name', 'project_name')
      UNION
      (#{users.to_sql})
      INTO OUTFILE '#{csv_name}' 
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';
    SQL
    User.connection.execute(sql)
  end

  def self.to_csv(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }

    users = User.readonly.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]
    users = User.where(id: users.first.id..users.last.id)
                .left_joins(:projects)
                .select("users.id, users.name, projects.name AS project_name")
                .order("users.id ASC, projects.id ASC")
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      users.in_batches.each_record do |row|
        csv << [row.id, row.name, row.project_name]
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
        if !project_names.empty?
          project_names.each { |p_name| csv << [row.id, row.name, p_name] }
        else
          csv << [row.id, row.name, ""]
        end
      end
    end
  end
end
