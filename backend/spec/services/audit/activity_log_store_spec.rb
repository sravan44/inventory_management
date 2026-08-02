require "rails_helper"

module Audit
  RSpec.describe ActivityLogStore do
    subject(:store) { described_class.new }

    def doc(action:, tenant_id:, at:)
      { "action" => action, "tenant_id" => tenant_id.to_s, "occurred_at" => at, "metadata" => {} }
    end

    it "is idempotent: re-inserting the same stream id doesn't duplicate" do
      store.insert("1-0", doc(action: "a", tenant_id: 1, at: "2026-07-25T10:00:00Z"))
      store.insert("1-0", doc(action: "a", tenant_id: 1, at: "2026-07-25T10:00:00Z"))
      expect(store.for_day("2026-07-25", tenant_id: 1).size).to eq(1)
    end

    it "buckets logs by day and scopes by tenant" do
      store.insert("1-0", doc(action: "a", tenant_id: 1, at: "2026-07-25T10:00:00Z"))
      store.insert("2-0", doc(action: "b", tenant_id: 1, at: "2026-07-26T10:00:00Z"))
      store.insert("3-0", doc(action: "c", tenant_id: 2, at: "2026-07-25T10:00:00Z"))

      day = store.for_day("2026-07-25", tenant_id: 1)
      expect(day.map { |r| r["action"] }).to eq([ "a" ])
    end

    it "keyword-searches action/metadata (case-insensitive), tenant-scoped" do
      store.insert("1-0", doc(action: "product.created", tenant_id: 1, at: "2026-07-25T10:00:00Z"))
      store.insert("2-0", doc(action: "stock.recorded", tenant_id: 1, at: "2026-07-25T11:00:00Z"))
      store.insert("3-0", doc(action: "product.created", tenant_id: 2, at: "2026-07-25T12:00:00Z"))

      results = store.search(tenant_id: 1, query: "PRODUCT")
      expect(results.map { |r| r["action"] }).to eq([ "product.created" ])
    end

    it "summarizes counts per day for a tenant" do
      store.insert("1-0", doc(action: "a", tenant_id: 1, at: "2026-07-25T10:00:00Z"))
      store.insert("2-0", doc(action: "b", tenant_id: 1, at: "2026-07-25T11:00:00Z"))
      store.insert("3-0", doc(action: "c", tenant_id: 1, at: "2026-07-26T09:00:00Z"))

      summary = store.day_counts(tenant_id: 1)
      expect(summary).to include({ "day" => "2026-07-25", "count" => 2 },
                                 { "day" => "2026-07-26", "count" => 1 })
    end
  end
end
