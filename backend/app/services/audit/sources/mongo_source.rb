# frozen_string_literal: true

module Audit
  module Sources
    # Structured audit logs from the Mongo store (tenant-scoped). Normalizes docs to
    # the common viewer entry shape.
    class MongoSource
      def self.enabled?
        true
      end

      def search(tenant_id:, filter:)
        Audit::ActivityLogStore.current
                               .query(tenant_id: tenant_id, **filter.transform_keys(&:to_sym))
                               .map { |doc| normalize(doc) }
      end

      private

      def normalize(doc)
        {
          "source" => "mongo",
          "action" => doc["action"],
          "message" => nil,
          "actor_type" => doc["actor_type"],
          "actor_id" => doc["actor_id"],
          "resource_type" => doc["resource_type"],
          "resource_id" => doc["resource_id"],
          "metadata" => doc["metadata"],
          "occurred_at" => doc["occurred_at"]
        }
      end
    end
  end
end
