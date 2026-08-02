require "rails_helper"

# API key management (admin users only) + the dual-auth consumption path
# (a key authenticating a tenant-scoped request). Apartment switch stubbed.
RSpec.describe "Api::V1::ApiKeys", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  def user_headers(user)
    {
      "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}",
      "HOST" => "acme.example.com"
    }
  end

  describe "POST /api/v1/api_keys" do
    it "creates a key and returns the raw token once (201)" do
      post "/api/v1/api_keys",
           params: { api_key: { name: "CI pipeline", role: "staff" } },
           headers: user_headers(admin)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to start_with("ik_")
      expect(body["name"]).to eq("CI pipeline")
    end

    it "403 when the caller is not an admin" do
      staff = create(:user)
      create(:membership, user: staff, tenant: tenant, role: :staff, status: :active)

      post "/api/v1/api_keys",
           params: { api_key: { name: "x" } },
           headers: user_headers(staff)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/api_keys" do
    it "lists keys WITHOUT the raw token" do
      create(:api_key, tenant: tenant, name: "existing")

      get "/api/v1/api_keys", headers: user_headers(admin)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first).not_to have_key("token")
      expect(body.map { |k| k["name"] }).to include("existing")
    end
  end

  describe "DELETE /api/v1/api_keys/:id" do
    it "revokes a key (204)" do
      key = create(:api_key, tenant: tenant)

      delete "/api/v1/api_keys/#{key.id}", headers: user_headers(admin)

      expect(response).to have_http_status(:no_content)
      expect(key.reload).to be_revoked
    end
  end

  describe "consuming the API WITH a key (dual auth)" do
    it "authenticates a tenant-scoped request via Api-Key" do
      _record, raw = Identity::ApiKey.issue(tenant: tenant, name: "CI", role: :staff)

      get "/api/v1/context",
          headers: { "Authorization" => "Api-Key #{raw}", "HOST" => "acme.example.com" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["actor_type"]).to eq("api_key")
      expect(body["role"]).to eq("staff")
    end

    it "rejects a key that belongs to a different tenant (403)" do
      other = create(:tenant, subdomain: "beta")
      _record, raw = Identity::ApiKey.issue(tenant: other, name: "wrong")

      get "/api/v1/context",
          headers: { "Authorization" => "Api-Key #{raw}", "HOST" => "acme.example.com" }

      expect(response).to have_http_status(:forbidden)
    end

    it "401 for a bogus key" do
      get "/api/v1/context",
          headers: { "Authorization" => "Api-Key ik_nope", "HOST" => "acme.example.com" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
