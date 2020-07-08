# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  description :text(65535)
#  due_on      :date
#  name        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_projects_on_name  (name) UNIQUE
#
require 'csv'
class Project < ApplicationRecord
  BOM = "\uFEFF"
  TIME_FORMAT = '%F_%H_%M_%S_%L%Z'
  CSV_HEADERS = %w[id name description].freeze

  validates :name, presence: true, uniqueness: { case_sensitive: true }

  def self.csv_name
    "#{Rails.root}/csvs/projects_#{Time.zone.now.strftime(TIME_FORMAT)}.csv"
  end

  def self.to_csv_by_sql(opts = {})
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    if adapter == 'mysql2'
      sql =
        "(SELECT 'id', 'name', 'description') " \
        "UNION " \
        "(SELECT #{CSV_HEADERS.join(', ')} " \
        " FROM projects " \
        " ORDER BY id ASC "
      sql += " LIMIT #{opts[:limit]} " if opts[:limit]
      sql += " OFFSET #{opts[:offset]} " if opts[:offset]
      sql +=
        ') ' \
        "INTO OUTFILE '#{csv_name}' " \
        "FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';"
        Project.connection.execute(sql)
    elsif adapter == "sqlite3"
      sql = 'SELECT id, name, description FROM projects ORDER BY id'
      sql += "OFFSET #{opts[:offset]} " if opts[:offset]
      sql += "LIMIT #{opts[:limit]} " if opts[:limit]
      sql += ';'
      db_name =
        Rails.configuration.database_configuration[Rails.env]['database']
      cmd = "sqlite3 -cmd '.headers on' -cmd '.mode csv' " \
        "-cmd '.output #{csv_name}' " \
        "#{db_name} '#{sql}'"
      system cmd
    else
      raise "No suport the db dapter: #{adapter}"
    end
  end

  # See
  # https://qiita.com/Akiyah/items/11edd64beed301f9f485
  # BOM付きCSVファイルを生成する
  def self.to_csv(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }
    projects = Project.order(:id)
    projects = projects.offset(opts[:offset].to_i) if opts[:offset]
    projects = projects.limit(opts[:limit].to_i) if opts[:limit]
    projects = projects.select(*CSV_HEADERS)

    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      projects.order(:id).in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end

  def self.to_csv_x(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }
    projects = Project.order(:id)
    projects = projects.offset(opts[:offset].to_i) if opts[:offset]
    projects = projects.limit(opts[:limit].to_i) if opts[:limit]

    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      projects.order(:id).in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end
end
