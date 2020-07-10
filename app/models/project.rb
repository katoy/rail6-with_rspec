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

  has_many :project_user_relations
  has_many :users, through: :project_user_relations

  def self.csv_name
    "#{Rails.root}/csvs/projects_#{Time.zone.now.strftime(TIME_FORMAT)}.csv"
  end

  def self.to_csv_by_sql(opts = {})
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    raise "No suport the db dapter: #{adapter}" if adapter != 'mysql2'

    projects = target_ar(opts)
    sql = <<-SQL.squish
      (SELECT 'id', 'name', 'description')
      UNION
      (#{projects.to_sql})
      INTO OUTFILE '#{csv_name}'
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';
    SQL
    Project.connection.execute(sql)
  end

  # See
  # https://qiita.com/Akiyah/items/11edd64beed301f9f485
  # BOM付きCSVファイルを生成する
  def self.to_csv(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }
    projects = target_ar(opts)
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      projects.in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end

  # select をしない版
  def self.to_csv_x(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }
    projects = opts[:projects] || Project.order(:id)
    projects = projects.offset(opts[:offset].to_i) if opts[:offset]
    projects = projects.limit(opts[:limit].to_i) if opts[:limit]

    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      projects.in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end

  # 単純に each する版
  def self.to_csv_x2(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }
    projects = target_ar(opts)
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      projects.each do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end

  def self.target_ar(opts)
    projects = opts[:projects] || Project.readonly.order(:id)
    projects = projects.offset(opts[:offset].to_i) if opts[:offset]
    projects = projects.limit(opts[:limit].to_i) if opts[:limit]
    projects.select(*CSV_HEADERS)
  end
end
