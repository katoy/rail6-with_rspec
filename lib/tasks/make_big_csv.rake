# frozen_string_literal: true

require 'progress_bar'

class Array
  include ProgressBar::WithProgress
end

namespace :db do
  desc "大量の Project の csv を STDOUT に出力する (porject_num,default:10_000)" \
  # usege: $ rails 'db:make_big_csv[10000000]' | gzip -c > csvs/10_000_000.gz
  #        $ gzcat csvs/csvs/10_000_000.gz
  task :make_big_csv, %i[project] => :environment do |_t, args|
    def make_projects(num)
      times =
        '"2020-01-31",' \
        '"2020-01-02 08:59:00.000000","2020-01-02 08:59:00.000000"'

      puts '"id","name","description","due_on","created_at","updated_at"'
      num.times do |idx|
        id = idx + 1
        puts "\"#{id}\",\"Project #{id}\",\"Description #{idx}\",#{times}"
      end
    end

    project_num = (args.project || 10_000).to_i
    make_projects(project_num)
  end
end
