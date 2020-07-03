# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id          :integer          not null, primary key
#  description :text
#  due_on      :date
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require 'csv'
class Project < ApplicationRecord
  BOM = "\uFEFF"
  TIME_FORMAT = '%F_%H_%M_%S_%L%Z'

  validates :name, presence: true, uniqueness: true

  def self.csv_name
    "#{Rails.root}/csvs/projects_#{Time.zone.now.strftime(TIME_FORMAT)}.csv"
  end

  def self.to_csv_by_sql
    sql = 'SELECT id, name, description FROM projects ORDER BY id;'
    db_name = Rails.configuration.database_configuration[Rails.env]['database']
    cmd = "sqlite3 -cmd '.headers on' -cmd '.mode csv' " \
      "-cmd '.output #{csv_name}' " \
      "#{db_name} '#{sql}'"
    system cmd
  end

  # See
  # https://qiita.com/Akiyah/items/11edd64beed301f9f485
  # BOM付きCSVファイルを生成する
  def self.to_csv
    headers = %w[id name description]
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, headers: headers, write_headers: true)
      Project.order(:id).in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end
end
