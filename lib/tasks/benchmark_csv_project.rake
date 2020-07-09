# frozen_string_literal: true

require 'benchmark'
require 'benchmark/memory'

namespace :benchmark do
  namespace :csv do
  desc "benchmark for project csv export, (offset, limit はオプション指定)"
    task :project, %i[offset limit] => :environment do |_t, args|
      opts = {}
      opts[:offset] = args.offset.to_i if args.offset
      opts[:limit] = args.limit.to_i if args.limit
      p opts

      Benchmark.bm 12 do |r|
        r.report "to_csv_by_sql" do
          Project.to_csv_by_sql(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv" do
          Project.to_csv(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv_x2" do
          Project.to_csv_x2(opts)
        end
      end

      Benchmark.memory do |r|
        r.report "to_csv_by_sql" do
          Project.to_csv_by_sql(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv" do
          Project.to_csv(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv_x2" do
          Project.to_csv_x2(opts)
        end
      end

      puts "#--- to delete generaed csv, rm csvs/*.csv"
    end
  end
end
