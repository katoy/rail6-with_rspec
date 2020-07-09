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

  def self.to_csv(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }

    users = opts[:projects] || User.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]
    users = users.joins(:projects)
                 .select("users.id, users.name, projects.name AS project_name")
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      users.in_batches.each_record do |row|
        csv << [row.id, row.name, row.project_name]
      end
    end
  end

  def self.to_csv_x(opts = {})
    csv_options = {
      headers: CSV_HEADERS, write_headers: true,
      quote_char: '"', force_quotes: true
    }

    users = opts[:projects] || User.order(:id)
    users = users.offset(opts[:offset].to_i) if opts[:offset]
    users = users.limit(opts[:limit].to_i) if opts[:limit]

    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, **csv_options)
      users.in_batches.each_record do |row|
        project_names = row.projects.order(:id).map(&:name)
        project_names.each { |p_name| csv << [row.id, row.name, p_name] }
      end
    end
  end
end
