require "rails_helper"

module Audit
  RSpec.describe ActivityStream do
    it "publishes an entry to the Redis stream" do
      entry = ActivityLog.new(
        tenant_id: 1, actor_type: "Identity::User", actor_id: 2,
        action: "product.created", resource_type: "Inventory::Product", resource_id: 3,
        metadata: { sku: "ABC-1" }, occurred_at: Time.current.utc.iso8601
      )

      expect { described_class.publish(entry) }
        .to change { described_class.redis.xlen(ActivityStream::STREAM_KEY) }.by(1)
    end

    it "serializes metadata as JSON in the stream fields" do
      entry = ActivityLog.new(action: "x", metadata: { a: 1 }, occurred_at: "t")
      described_class.publish(entry)

      _id, fields = described_class.redis.xrange(ActivityStream::STREAM_KEY, "-", "+").last
      expect(JSON.parse(fields["metadata"])).to eq("a" => 1)
      expect(fields["action"]).to eq("x")
    end
  end
end
