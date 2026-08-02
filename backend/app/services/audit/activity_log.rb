# frozen_string_literal: true

module Audit
  # A single audit/activity event (ADR-0007). Plain value object; serialized to a
  # flat string hash for the Redis stream (stream fields must be strings).
  ActivityLog = Struct.new(
    :tenant_id, :actor_type, :actor_id, :action,
    :resource_type, :resource_id, :metadata, :occurred_at,
    keyword_init: true
  ) do
    def to_stream_hash
      {
        "tenant_id" => tenant_id.to_s,
        "actor_type" => actor_type.to_s,
        "actor_id" => actor_id.to_s,
        "action" => action.to_s,
        "resource_type" => resource_type.to_s,
        "resource_id" => resource_id.to_s,
        "metadata" => (metadata || {}).to_json,
        "occurred_at" => occurred_at.to_s
      }
    end
  end
end
