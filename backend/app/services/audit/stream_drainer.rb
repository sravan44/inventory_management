# frozen_string_literal: true

module Audit
  # Drains the Redis activity stream into the durable store (ADR-0007). Uses a
  # consumer GROUP for at-least-once delivery: read pending entries, write to
  # Mongo (idempotent by entry id), then XACK. Run in a loop via `rake audit:drain`
  # (a dedicated worker process); Sidekiq can schedule it later.
  class StreamDrainer
    GROUP = "mongo_sink"
    CONSUMER = ENV.fetch("HOSTNAME", "drainer-1")

    def self.drain_batch(count: 100, block_ms: 5000)
      ensure_group

      result = redis.xreadgroup(GROUP, CONSUMER, ActivityStream::STREAM_KEY, ">",
                                count: count, block: block_ms)
      messages = result && result[ActivityStream::STREAM_KEY]
      return 0 if messages.blank?

      messages.each do |id, fields|
        ActivityLogStore.current.insert(id, normalize(fields))
        redis.xack(ActivityStream::STREAM_KEY, GROUP, id)
      end
      messages.size
    end

    def self.ensure_group
      redis.xgroup(:create, ActivityStream::STREAM_KEY, GROUP, "$", mkstream: true)
    rescue Redis::CommandError => e
      raise unless e.message.include?("BUSYGROUP") # group already exists — fine
    end

    # Stream fields are strings; decode metadata back to a hash.
    def self.normalize(fields)
      doc = fields.dup
      doc["metadata"] = JSON.parse(doc["metadata"]) rescue {} # rubocop:disable Style/RescueModifier
      doc
    end

    def self.redis
      ActivityStream.redis
    end
  end
end
