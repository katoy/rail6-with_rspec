# frozen_string_literal: true

# == Schema Information
#
# Table name: project_user_relations
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_user_relations_on_project_id  (project_id)
#  index_project_user_relations_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#

# Indexes
#
#  index_project_user_relations_on_project_id              (project_id)
#  index_project_user_relations_on_project_id_and_user_id  (project_id,user_id)
#  index_project_user_relations_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
require 'csv'

class ProjectUserRelation < ApplicationRecord
  CSV_DATETIME_FORMAT = '%F %H:%M:%S'
  UTC_OFFSET = '+09:00'

  belongs_to :project
  belongs_to :user

  validates :project, presence: true
  validates :user,    presence: true

  def self.export(file_path)
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    raise "No suport the db dapter: #{adapter}" if adapter != 'mysql2'

    select_sql =
      ProjectUserRelation.columns.map { |x| [x.name.to_s, x.type] }.map do |col|
        if col[1] == :datetime
          "CASE" \
          "  WHEN project_user_relations.#{col[0]} IS NULL THEN ''" \
          "  ELSE convert_tz(" \
          "    project_user_relations.#{col[0]}, '+00:00','#{UTC_OFFSET}') " \
          "END AS #{col[0]}"
        else
          "CASE" \
          "  WHEN project_user_relations.#{col[0]} IS NULL THEN ''" \
          "  ELSE project_user_relations.#{col[0]} " \
          "END AS #{col[0]}"
        end
      end.join(',')

    sql = <<-SQL.squish
      (SELECT '#{ProjectUserRelation.column_names.join('\',\'')}')
      UNION
      (SELECT #{select_sql} FROM project_user_relations)
      INTO OUTFILE ?
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';
    SQL
    sql = ProjectUserRelation.sanitize_sql([sql, file_path])
    ProjectUserRelation.connection.execute(sql)
  end

  def self.import_by_sql(file_path)
    adapter = Rails.configuration.database_configuration[Rails.env]["adapter"]
    raise "No suport the db dapter: #{adapter}" if adapter != 'mysql2'

    sql = <<-SQL.squish
      LOAD DATA LOCAL INFILE ?
      INTO TABLE project_user_relations
      FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;
    SQL
    sql = ProjectUserRelation.sanitize_sql([sql, file_path])
    ProjectUserRelation.connection.execute(sql)
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

      rows << row_hash
      if rows.size > 1000
        # ProjectUserRelation.upsert_all(rows)
        ProjectUserRelation.insert_all(rows)
        rows = []
      end
    end
    ProjectUserRelation.insert_all(rows) if rows.size.positive?
  end

  def self.import_x(file_path)
    CSV.foreach(file_path, headers: true) do |row|
      ProjectUserRelation.find_or_create_by(row.to_hash)
    end
  end
end
