# frozen_string_literal: true

require 'benchmark'
require 'benchmark/memory'

namespace :benchmark do
  namespace :import do
  desc "benchmark for project csv import"
    task :project, %i[file] => :environment do |_t, args|
      file = args.file

      Benchmark.bm 12 do |r|
        ActiveRecord::Base.connection.query_cache.clear
        r.report "import_x" do
          Project.import_x(file)
        end
      end

      Benchmark.memory do |r|
        ActiveRecord::Base.connection.query_cache.clear
        r.report "import_x" do
          Project.import_x(file)
        end
      end

      puts "Project.count: #{Project.count}"
      system("wc -l #{file}")
    end
  end
end
