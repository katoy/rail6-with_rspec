# frozen_string_literal: true

require 'benchmark'
require 'benchmark/memory'

namespace :benchmark do
  namespace :csv do
    desc "benchmark for user csv export, (offset, limit はオプション指定)"
    task :user, %i[offset limit] => :environment do |_t, args|
      opts = {}
      opts[:offset] = args.offset.to_i if args.offset
      opts[:limit] = args.limit.to_i if args.limit
      p opts

      Benchmark.bm 12 do |r|
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv" do
          User.to_csv(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv_x" do
          User.to_csv_x(opts)
        end
      end

      Benchmark.memory do |r|
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv" do
          User.to_csv(opts)
        end
        ActiveRecord::Base.connection.query_cache.clear
        r.report "to_csv_x" do
          User.to_csv_x(opts)
        end
      end

      puts "#--- to delete generaed csv, rm csvs/*.csv"
    end
  end
end
