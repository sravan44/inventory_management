# frozen_string_literal: true

module Audit
  # Durable audit-log store (ADR-0007). MongoDB in dev/prod; an in-memory backing
  # in test (no Mongo needed for specs/CI). Documents are keyed by the Redis stream
  # entry id, so re-draining is idempotent. Every doc carries a `day` (YYYY-MM-DD)
  # for day-wise management, and a TTL index expires old logs after N days.
  class ActivityLogStore
    COLLECTION = "activity_logs"
    RETENTION_DAYS = Integer(ENV.fetch("AUDIT_RETENTION_DAYS", "90"))

    def self.current
      @current ||= new
    end

    def self.reset!
      @current = nil
    end

    def initialize
      if Rails.env.test?
        @memory = {}
      else
        ensure_indexes
      end
    end

    # Idempotent upsert keyed by the stream entry id.
    def insert(id, doc)
      record = doc.merge(
        "_id" => id,
        "day" => day_for(doc["occurred_at"]),
        "created_at" => Time.now.utc,
        "search_text" => search_text_for(doc)
      )

      if @memory
        @memory[id] ||= record
      else
        collection.update_one({ _id: id }, { "$setOnInsert" => record }, upsert: true)
      end
      record
    end

    # All logs for a given day (YYYY-MM-DD), newest first, scoped to a tenant.
    def for_day(day, tenant_id: nil)
      if @memory
        @memory.values
               .select { |r| r["day"] == day && tenant_match?(r, tenant_id) }
               .sort_by { |r| r["occurred_at"].to_s }.reverse
      else
        query = { day: day }
        query[:tenant_id] = tenant_id.to_s if tenant_id
        collection.find(query).sort(occurred_at: -1).to_a
      end
    end

    # Keyword search over action / resource / metadata (case-insensitive), scoped
    # to a tenant and optionally a day. Foundation for the log-search UI; swap for
    # a real search engine (Meilisearch/OpenSearch) at scale.
    def search(tenant_id:, query:, day: nil, limit: 200)
      needle = query.to_s.downcase

      if @memory
        @memory.values
               .select { |r| tenant_match?(r, tenant_id) && (day.nil? || r["day"] == day) && r["search_text"].to_s.include?(needle) }
               .sort_by { |r| r["occurred_at"].to_s }.reverse.first(limit)
      else
        filter = { tenant_id: tenant_id.to_s, search_text: /#{Regexp.escape(needle)}/ }
        filter[:day] = day if day
        collection.find(filter).sort(occurred_at: -1).limit(limit).to_a
      end
    end

    # Structured query used by the log viewer: substring on action/metadata, an
    # actor type, and a day range — all optional. Safe: callers pass a sanitized,
    # allow-listed filter (Audit::LogSearch).
    def query(tenant_id:, action_contains: nil, actor_type: nil, date_from: nil, date_to: nil, limit: 200)
      if @memory
        needle = action_contains.to_s.downcase
        @memory.values.select do |r|
          tenant_match?(r, tenant_id) &&
            (action_contains.nil? || r["search_text"].to_s.include?(needle)) &&
            (actor_type.nil? || r["actor_type"] == actor_type) &&
            (date_from.nil? || r["day"] >= date_from) &&
            (date_to.nil? || r["day"] <= date_to)
        end.sort_by { |r| r["occurred_at"].to_s }.reverse.first(limit)
      else
        filter = { tenant_id: tenant_id.to_s }
        filter[:search_text] = /#{Regexp.escape(action_contains.downcase)}/ if action_contains
        filter[:actor_type] = actor_type if actor_type
        if date_from || date_to
          range = {}
          range["$gte"] = date_from if date_from
          range["$lte"] = date_to if date_to
          filter[:day] = range
        end
        collection.find(filter).sort(occurred_at: -1).limit(limit).to_a
      end
    end

    # Count of logs per day, for a day-wise overview.
    def day_counts(tenant_id: nil)
      if @memory
        @memory.values
               .select { |r| tenant_match?(r, tenant_id) }
               .group_by { |r| r["day"] }
               .map { |day, rows| { "day" => day, "count" => rows.size } }
               .sort_by { |h| h["day"] }
      else
        match = tenant_id ? { tenant_id: tenant_id.to_s } : {}
        collection.aggregate([
          { "$match" => match },
          { "$group" => { _id: "$day", count: { "$sum" => 1 } } },
          { "$sort" => { _id: 1 } }
        ]).map { |r| { "day" => r["_id"], "count" => r["count"] } }
      end
    end

    private

    def tenant_match?(record, tenant_id)
      tenant_id.nil? || record["tenant_id"].to_s == tenant_id.to_s
    end

    def search_text_for(doc)
      meta = doc["metadata"]
      meta_text = meta.is_a?(Hash) ? meta.values.join(" ") : meta.to_s
      [ doc["action"], doc["resource_type"], meta_text ].compact.join(" ").downcase
    end

    def day_for(occurred_at)
      Time.parse(occurred_at.to_s).utc.to_date.iso8601
    rescue ArgumentError, TypeError
      Time.current.utc.to_date.iso8601
    end

    def collection
      @collection ||= mongo_client.database[COLLECTION]
    end

    def mongo_client
      @mongo_client ||= Mongo::Client.new(
        ENV.fetch("MONGO_URL", "mongodb://mongo:27017/inventory_audit")
      )
    end

    def ensure_indexes
      collection.indexes.create_many([
        { key: { day: 1, tenant_id: 1 } },
        { key: { occurred_at: -1 } },
        { key: { created_at: 1 }, expire_after: RETENTION_DAYS * 86_400 } # TTL retention
      ])
    rescue Mongo::Error
      nil # indexes already exist / mongo momentarily unavailable
    end
  end
end
