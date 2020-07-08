# frozen_string_literal: true

namespace :make_big_db do
  desc "大量の Pproject の DB をつくる(num; default:10_000)"
  task :projects, [:num] => :environment do |_t, args|
    # system "rails db:drop db:create db:migrate"
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE projects;")
    time = Time.zone.now
    num = 10_000
    num = args.num.to_i if args.num
    (num / 10_000).times do |k|
      attributes = 10_000.times.map do |idx|
        id = k * 10_000 + idx + 1
        {
          id: id,
          name: "Project #{id}",
          description: "Test project #{id}",
          created_at: time,
          updated_at: time
        }
      end
      Project.insert_all! attributes
    end

    if (num % 10_000).positive?
      attributes =  (num % 10_000).times.map do |idx|
        id = (num / 10_000) * 10_000 + idx + 1
        {
          id: id,
          name: "Project #{id}",
          description: "Test project #{id}",
          created_at: time,
          updated_at: time
        }
      end
      Project.insert_all! attributes
    end

    puts "#-- created #{Project.count} recoreds."
  end
end
