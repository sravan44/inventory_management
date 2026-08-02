require "rails_helper"

module Audit
  RSpec.describe LogViewer do
    before { ActivityLogStore.reset! }
    after  { ActivityLogStore.reset! }

    def seed(action:, tenant_id:, at:)
      ActivityLogStore.current.insert(
        "#{action}-#{at}",
        { "action" => action, "tenant_id" => tenant_id.to_s, "occurred_at" => at, "metadata" => {} }
      )
    end

    it "uses the LLM-translated filter when available" do
      seed(action: "user.login_failed", tenant_id: 1, at: "2026-07-25T10:00:00Z")
      seed(action: "product.created",   tenant_id: 1, at: "2026-07-25T11:00:00Z")

      allow(Audit::Llm).to receive(:translate).and_return("action_contains" => "login")

      result = described_class.search(text: "failed logins", tenant_id: 1)

      expect(result.filter).to eq("action_contains" => "login")
      expect(result.entries.map { |e| e["action"] }).to eq([ "user.login_failed" ])
    end

    it "falls back to keyword search when the LLM is unavailable" do
      seed(action: "product.created", tenant_id: 1, at: "2026-07-25T10:00:00Z")
      allow(Audit::Llm).to receive(:translate).and_return(nil)

      result = described_class.search(text: "product", tenant_id: 1)
      expect(result.entries.map { |e| e["action"] }).to eq([ "product.created" ])
    end

    it "tags entries with their source (mongo)" do
      seed(action: "x", tenant_id: 1, at: "2026-07-25T10:00:00Z")
      allow(Audit::Llm).to receive(:translate).and_return(nil)

      result = described_class.search(text: "x", tenant_id: 1)
      expect(result.entries.first["source"]).to eq("mongo")
    end
  end
end
