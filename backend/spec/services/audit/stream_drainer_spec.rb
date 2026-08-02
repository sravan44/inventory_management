require "rails_helper"

module Audit
  RSpec.describe StreamDrainer do
    before { ActivityLogStore.reset! }
    after  { ActivityLogStore.reset! }

    it "reads a batch from the group, writes to the store, and acks each entry" do
      redis = instance_double(Redis)
      allow(redis).to receive(:xgroup)
      allow(redis).to receive(:xreadgroup).and_return(
        ActivityStream::STREAM_KEY => [
          [ "5-0", {
            "action" => "product.created", "tenant_id" => "1",
            "occurred_at" => "2026-07-25T10:00:00Z", "metadata" => "{\"sku\":\"A\"}"
          } ]
        ]
      )
      allow(redis).to receive(:xack)
      allow(described_class).to receive(:redis).and_return(redis)

      wrote = described_class.drain_batch

      expect(wrote).to eq(1)
      expect(redis).to have_received(:xack).with(ActivityStream::STREAM_KEY, described_class::GROUP, "5-0")

      logs = ActivityLogStore.current.for_day("2026-07-25", tenant_id: 1)
      expect(logs.first["action"]).to eq("product.created")
      expect(logs.first["metadata"]).to eq("sku" => "A") # JSON decoded back to a hash
    end

    it "returns 0 when the stream has nothing new" do
      redis = instance_double(Redis)
      allow(redis).to receive(:xgroup)
      allow(redis).to receive(:xreadgroup).and_return(nil)
      allow(described_class).to receive(:redis).and_return(redis)

      expect(described_class.drain_batch).to eq(0)
    end
  end
end
