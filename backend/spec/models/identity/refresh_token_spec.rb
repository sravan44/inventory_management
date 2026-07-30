require "rails_helper"

module Identity
  RSpec.describe RefreshToken, type: :model do
    let(:user) { User.create!(email: "a@b.com", password: "secret123") }

    describe ".issue" do
      it "returns the record and the raw token, storing only the digest" do
        record, raw = RefreshToken.issue(user)

        expect(raw).to be_present
        expect(record.token_digest).to eq(Digest::SHA256.hexdigest(raw))
        expect(record.token_digest).not_to eq(raw)   # raw is never stored
        expect(record.expires_at).to be > Time.current
      end
    end

    describe ".find_active" do
      it "finds an active token by its raw value" do
        record, raw = RefreshToken.issue(user)
        expect(RefreshToken.find_active(raw)).to eq(record)
      end

      it "returns nil for an unknown token" do
        expect(RefreshToken.find_active("nope")).to be_nil
      end

      it "returns nil once revoked" do
        record, raw = RefreshToken.issue(user)
        record.revoke!
        expect(RefreshToken.find_active(raw)).to be_nil
      end

      it "returns nil once expired" do
        _record, raw = RefreshToken.issue(user, ttl: -1.second)
        expect(RefreshToken.find_active(raw)).to be_nil
      end
    end

    describe "#revoke!" do
      it "sets revoked_at and flips active?" do
        record, = RefreshToken.issue(user)
        expect(record.active?).to be(true)
        record.revoke!
        expect(record.revoked?).to be(true)
        expect(record.active?).to be(false)
      end
    end

    it "cleans up tokens when the user is destroyed" do
      RefreshToken.issue(user)
      expect { user.destroy }.to change(RefreshToken, :count).by(-1)
    end
  end
end
