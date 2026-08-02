# frozen_string_literal: true

module Audit
  # Sanitizes an LLM- (or user-) provided filter down to a strict allow-list. This
  # is the security boundary for NL search (ADR-0016): whatever the model returns,
  # only these keys/values ever reach a query, so a prompt can't produce arbitrary
  # Mongo or grep expressions.
  module LogSearch
    ALLOWED_ACTOR_TYPES = %w[Identity::User Identity::ApiKey].freeze

    def self.sanitize(raw)
      raw = raw.to_h.transform_keys(&:to_s)
      filter = {}
      filter["action_contains"] = raw["action_contains"].to_s if raw["action_contains"].present?
      filter["actor_type"] = raw["actor_type"] if ALLOWED_ACTOR_TYPES.include?(raw["actor_type"])
      filter["date_from"] = safe_date(raw["date_from"]) if raw["date_from"].present?
      filter["date_to"] = safe_date(raw["date_to"]) if raw["date_to"].present?
      filter.compact
    end

    def self.safe_date(value)
      Date.iso8601(value.to_s).iso8601
    rescue ArgumentError
      nil
    end
  end
end
