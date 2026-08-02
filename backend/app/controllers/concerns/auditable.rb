# frozen_string_literal: true

# Tiny helper for emitting audit events from controllers (ADR-0007/0016). Delegates
# to Audit::Logger, which captures the actor/tenant from Current and enqueues the
# emit job — so instrumenting an action is a one-liner that never blocks the request.
module Auditable
  extend ActiveSupport::Concern

  private

  def audit(action, resource: nil, metadata: {})
    Audit::Logger.log(action: action, resource: resource, metadata: metadata)
  end
end
