# frozen_string_literal: true

module Audit
  # Off-request: publish an audit event to the Redis stream. Thin wrapper so the
  # request path only pays an enqueue. Sidekiq (durable, Redis-backed) replaces the
  # default adapter later in this milestone.
  class EmitActivityLogJob < ApplicationJob
    queue_as :default

    def perform(attrs)
      entry = Audit::ActivityLog.new(**attrs.symbolize_keys)
      Audit::ActivityStream.publish(entry)
    end
  end
end
