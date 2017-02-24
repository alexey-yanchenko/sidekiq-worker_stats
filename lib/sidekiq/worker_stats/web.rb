require 'json'

require 'sidekiq/web' unless defined?(Sidekiq::Web)
require 'sidekiq/paginator'

module Sidekiq
  module WorkerStats
    module Web
      def self.registered(app)
        view_path = File.join(File.expand_path('..', __FILE__), 'views')

        app.get '/worker_stats' do

          @count = params["per_page"].to_i || 10
          @count = @count >= 1 ? @count : 10


          (@current_page, @total_size, @workers_stats ) = page(REDIS_HASH, params['page'], @count)
					@workers_stats = @workers_stats.map { |msg| JSON.parse(msg) }

          render(:erb, File.read(File.join(view_path, 'worker_stats.erb')))
        end

        app.get '/worker_stats/:key' do
          @key = params[:key]
          @worker = {}
          #Sidekiq.redis do |redis|
            ##@worker = JSON.parse(redis.hget(REDIS_HASH, @key))
          #end

          render(:erb, File.read(File.join(view_path, 'worker_stats_single.erb')))
        end
      end
    end
  end
end

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::WorkerStats::Web
  Sidekiq::Web.tabs['Worker Stats'] = 'worker_stats'
end
