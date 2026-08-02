# frozen_string_literal: true

module Audit
  # The Redis Stream buffer for audit events (ADR-0007). Fast, append-only
  # ingestion; a worker drains it to MongoDB (commit 5.2). `maxlen` caps the
  # stream so it can't grow unbounded if the drainer falls behind.
  class ActivityStream
    STREAM_KEY = "activity_logs"
    MAX_LEN = 100_000

    def self.publish(entry)
      redis.xadd(STREAM_KEY, entry.to_stream_hash, maxlen: MAX_LEN, approximate: true)
    end

    def self.redis
      @redis ||= build_redis
    end

    def self.build_redis
      if Rails.env.test?
        require "mock_redis"
        MockRedis.new
      else
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0"))
      end
    end
    private_class_method :build_redis
  end
end
