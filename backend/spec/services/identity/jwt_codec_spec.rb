require "rails_helper"

module Identity
  RSpec.describe JwtCodec do
    it "round-trips a payload and adds exp/iat" do
      token = described_class.encode({ sub: "42" })
      payload = described_class.decode(token)

      expect(payload["sub"]).to eq("42")
      expect(payload["exp"]).to be_present
      expect(payload["iat"]).to be_present
    end

    it "raises InvalidToken on a tampered token" do
      token = described_class.encode({ sub: "42" })
      expect { described_class.decode("#{token}tampered") }
        .to raise_error(JwtCodec::InvalidToken)
    end

    it "raises InvalidToken on an expired token" do
      token = described_class.encode({ sub: "42" }, ttl: -1.second)
      expect { described_class.decode(token) }
        .to raise_error(JwtCodec::InvalidToken)
    end
  end
end
