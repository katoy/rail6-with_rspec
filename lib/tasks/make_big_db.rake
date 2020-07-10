# frozen_string_literal: true

require 'progress_bar'

class Array
  include ProgressBar::WithProgress
end

namespace :db do
  desc "大量の Project の DB をつくる(porject_num, user_num; default:10_000)"
  task :make_big_db, %i[project user] => :environment do |_t, args|
    def attr_project(id, time)
      {
        id: id,
        name: "Project #{id}",
        description: "Test project #{id}",
        created_at: time,
        updated_at: time
      }
    end

    def attr_user(id, time)
      {
        id: id,
        name: "name_#{id}",
        email: "name_#{id}@example.com",
        created_at: time,
        updated_at: time
      }
    end

    def attr_relations(user_id, project_num, time)
      nums = [0, 1, 0, 0, 0, 3, 0, 0, 5, 0]

      ret = []
      nums[user_id % 10].times do |idx|
        ret << {
          user_id: user_id,
          project_id: (user_id + idx) % project_num + 1,
          created_at: time, updated_at: time
        }
      end
      ret.uniq
    end

    def make_projects(num)
      time = Time.zone.now
      id = 0
      (num / 1000).times.to_a.with_progress do |_k|
        attributes = 1000.times.map do |_idx|
          id += 1
          attr_project(id, time)
        end
        Project.insert_all! attributes
      end
      puts("\n")

      return unless (num % 1000).positive?

      attributes = (num % 1000).times.map do |_idx|
        id += 1
        attr_project(id, time)
      end
      Project.insert_all! attributes
    end

    def make_users(num)
      time = Time.zone.now
      id = 0
      (num / 1000).times.to_a.with_progress do |_k|
        attributes = 1000.times.map do |_idx|
          id += 1
          attr_user(id, time)
        end
        User.insert_all! attributes
      end
      puts("\n")

      return unless (num % 1000).positive?

      attributes = (num % 1000).times.map do |_idx|
        id += 1
        attr_user(id, time)
      end
      User.insert_all! attributes
    end

    def make_relations(project_num, user_num)
      time = Time.zone.now
      user_id = 0
      (user_num / 1000).times.to_a.with_progress do |_k|
        attributes = []
        1000.times.map do |_idx|
          user_id += 1
          attributes += attr_relations(user_id, project_num, time)
        end
        ProjectUserRelation.insert_all! attributes
      end
      puts("\n")

      return unless (user_num % 1000).positive?

      attributes = []
      (user_num % 1000).times.map do |_idx|
        user_id += 1
        attributes += attr_relations(user_id, project_num, time)
      end
      ProjectUserRelation.insert_all! attributes
    end

    system("rails db:drop")
    system("rails db:create")
    system("rails db:migrate")

    ProjectUserRelation.delete_all
    Project.delete_all
    User.delete_all

    project_num = (args.project || 10_000).to_i
    user_num = (args.user || 10_000).to_i

    make_projects(project_num)
    make_users(user_num)
    make_relations(project_num, user_num)

    puts "#-- created"
    puts "#--               project #{Project.count} recoreds."
    puts "#--                  user #{User.count} recoreds."
    puts "#-- project_user_relation #{ProjectUserRelation.count} recoreds."
  end
end
