require "rails_helper"

module Identity
  RSpec.describe ApiKey, type: :model do
    let(:tenant) { create(:tenant) }

    describe ".issue" do
      it "returns [record, raw] with an ik_ prefix and stores only the digest" do
        record, raw = ApiKey.issue(tenant: tenant, name: "CI", role: :staff)

        expect(raw).to start_with("ik_")
        expect(record.token_digest).to eq(Digest::SHA256.hexdigest(raw))
        expect(record.token_digest).not_to include(raw)
        expect(record.role).to eq("staff")
      end
    end

    describe ".find_active" do
      it "finds an active key by raw value" do
        record, raw = ApiKey.issue(tenant: tenant, name: "CI")
        expect(ApiKey.find_active(raw)).to eq(record)
      end

      it "returns nil for unknown / blank" do
        expect(ApiKey.find_active("nope")).to be_nil
        expect(ApiKey.find_active("")).to be_nil
      end

      it "returns nil once revoked" do
        record, raw = ApiKey.issue(tenant: tenant, name: "CI")
        record.revoke!
        expect(ApiKey.find_active(raw)).to be_nil
      end

      it "returns nil once expired" do
        _record, raw = ApiKey.issue(tenant: tenant, name: "CI", expires_at: 1.second.ago)
        expect(ApiKey.find_active(raw)).to be_nil
      end
    end

    it "treats a nil expiry as never-expiring" do
      record, raw = ApiKey.issue(tenant: tenant, name: "CI")
      expect(record.expires_at).to be_nil
      expect(ApiKey.find_active(raw)).to eq(record)
    end
  end
end
