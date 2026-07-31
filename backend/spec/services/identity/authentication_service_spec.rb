require "rails_helper"

module Identity
  RSpec.describe AuthenticationService do
    let!(:user) { User.create!(email: "sam@acme.io", password: "hunter2pw") }

    describe ".authenticate" do
      it "returns a token pair for valid credentials (email case-insensitive)" do
        result = described_class.authenticate(email: "SAM@acme.io", password: "hunter2pw")

        expect(result.user).to eq(user)
        expect(result.access_token).to be_present
        expect(result.refresh_token).to be_present
      end

      it "raises on a wrong password" do
        expect { described_class.authenticate(email: "sam@acme.io", password: "nope") }
          .to raise_error(AuthenticationService::InvalidCredentials)
      end

      it "raises on an unknown email" do
        expect { described_class.authenticate(email: "ghost@acme.io", password: "x") }
          .to raise_error(AuthenticationService::InvalidCredentials)
      end
    end

    describe ".refresh" do
      it "rotates: consumes the old refresh token and issues a new pair" do
        first  = described_class.authenticate(email: "sam@acme.io", password: "hunter2pw")
        second = described_class.refresh(first.refresh_token)

        expect(second.access_token).to be_present
        expect(second.refresh_token).not_to eq(first.refresh_token)

        # the old refresh token is now single-use-spent
        expect { described_class.refresh(first.refresh_token) }
          .to raise_error(AuthenticationService::InvalidRefreshToken)
      end

      it "detects reuse of a revoked token and revokes ALL the user's tokens" do
        first  = described_class.authenticate(email: "sam@acme.io", password: "hunter2pw")
        second = described_class.refresh(first.refresh_token) # first now revoked

        # replaying the revoked `first` token is treated as theft
        expect { described_class.refresh(first.refresh_token) }
          .to raise_error(AuthenticationService::InvalidRefreshToken)

        # ...and the currently-valid `second` token is killed too
        expect(RefreshToken.find_active(second.refresh_token)).to be_nil
      end
    end

    describe ".revoke_all" do
      it "revokes every active token for the user" do
        described_class.authenticate(email: "sam@acme.io", password: "hunter2pw")
        described_class.authenticate(email: "sam@acme.io", password: "hunter2pw")

        expect { described_class.revoke_all(user) }
          .to change { user.refresh_tokens.where(revoked_at: nil).count }.to(0)
      end
    end
  end
end
