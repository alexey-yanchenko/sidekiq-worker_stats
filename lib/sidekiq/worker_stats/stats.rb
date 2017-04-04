require 'sidekiq'
require 'json'

module Sidekiq
  module WorkerStats
    class Stats
      attr_reader :pid
      attr_reader :jid
      attr_reader :queue
      attr_reader :klass
      attr_reader :args

      attr_reader :start_t
      attr_reader :stop_t
      attr_reader :walltime
      attr_reader :status
      attr_reader :mem

      attr_reader :mem_thr
      attr_reader :config

      def initialize(worker, msg, queue, config)
        @config = config
        @queue = queue
        @klass = worker.class
        @pid = ::Process.pid
        @jid = worker.jid
        @mem = {}
        #@args = msg["args"]
        start
      end

      def start
        @status = 'started'
        @start_t = ::Time.now.to_f
        @mem[::Time.now.to_f] = current_memory
      end

      def stop(status)
        @stop_t = ::Time.now.to_f
        @walltime = @stop_t - @start_t
        @status = status
        @mem[::Time.now.to_f] = current_memory
      end

      def save
        #worker_key = "#{@klass}:#{@start_t}:#{@jid}"
        data = {
          pid: @pid,
          jid: @jid,
          queue: @queue,
          class: @klass,
          processor: identity,
          start: @start_t,
          stop: @stop_t,
          walltime: @walltime,
          status: @status,
          mem: @mem
        }

        Sidekiq.redis do |redis|
          redis.lpush ::Sidekiq::WorkerStats::REDIS_HASH, JSON.generate(data)
          redis.ltrim ::Sidekiq::WorkerStats::REDIS_HASH, 0, 1000
        end
      end

      private

      def hostname
        Socket.gethostname
      end

      def identity
        @@identity ||= "#{hostname}:#{$$}"
      end

      def current_memory
        `ps -o rss= -p #{@pid}`.strip.to_i * 1024
      end

      # Remove old samples if number of samples > @config.max_samples
      def remove_old_samples
        keys = nil
        Sidekiq.redis do |redis|
          keys = redis.hkeys ::Sidekiq::WorkerStats::REDIS_HASH
        end

        return if keys.length <= @config.max_samples

        keys = keys.map { |k| k.split(':') if k.start_with?(@klass.to_s) }.compact

        return if keys.length <= @config.max_samples

        keys.sort! { |x, y| x[1] <=> y[1] }
        keys = keys.map { |k| k.join(':') }

        Sidekiq.redis do |redis|
          keys[0..keys.length - @config.max_samples - 1].each do |k|
            redis.hdel ::Sidekiq::WorkerStats::REDIS_HASH, k
          end
        end
      end
    end
  end
end
