require "rails_helper"

# Tenant-scoped, admin-only membership management. Apartment switch stubbed
# (we're testing the endpoints + authorization, not schema machinery).
RSpec.describe "Api::V1::Memberships", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  def headers_for(user)
    {
      "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}",
      "HOST" => "acme.example.com"
    }
  end

  describe "POST /api/v1/memberships (invite)" do
    it "invites an email as an invited membership (201)" do
      post "/api/v1/memberships",
           params: { membership: { email: "new@acme.io", role: "staff" } },
           headers: headers_for(admin)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["user"]["email"]).to eq("new@acme.io")
      expect(body["status"]).to eq("invited")
      expect(body["role"]).to eq("staff")
    end

    it "403 when the caller is not an admin" do
      staff = create(:user)
      create(:membership, user: staff, tenant: tenant, role: :staff, status: :active)

      post "/api/v1/memberships",
           params: { membership: { email: "x@acme.io", role: "staff" } },
           headers: headers_for(staff)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/memberships/:id (revoke)" do
    it "revokes the membership (204)" do
      target = create(:membership, tenant: tenant, role: :staff, status: :active)

      delete "/api/v1/memberships/#{target.id}", headers: headers_for(admin)

      expect(response).to have_http_status(:no_content)
      expect(target.reload).to be_revoked
    end

    it "404 for a membership in another tenant" do
      other = create(:membership, role: :staff, status: :active) # different tenant via factory

      delete "/api/v1/memberships/#{other.id}", headers: headers_for(admin)

      expect(response).to have_http_status(:not_found)
    end
  end
end
