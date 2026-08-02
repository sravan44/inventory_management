# frozen_string_literal: true

module Audit
  # Facade for emitting audit events. Call `Audit::Logger.log(...)` from
  # state-changing operations (wired in commit 5.3). It captures the request
  # context from Current, builds an ActivityLog, and enqueues the emit job — so the
  # request never blocks on (or fails because of) logging.
  class Logger
    def self.log(action:, resource: nil, metadata: {})
      entry = ActivityLog.new(
        tenant_id: Current.tenant&.id,
        actor_type: Current.actor&.class&.name,
        actor_id: Current.actor&.id,
        action: action,
        resource_type: resource&.class&.name,
        resource_id: resource&.id,
        metadata: metadata,
        occurred_at: Time.current.utc.iso8601
      )
      EmitActivityLogJob.perform_later(entry.to_h.stringify_keys)
    end
  end
end
