require "rails_helper"

# Exercises the tenant-scoped stack end to end: tenant resolution (subdomain) +
# authentication (JWT) + membership gate. Apartment's schema switch is stubbed —
# we're testing the gate, not the schema machinery (covered by provisioning specs).
RSpec.describe "Api::V1::Context", type: :request do
  let!(:tenant) { Identity::Tenant.create!(name: "Acme", subdomain: "acme", status: :active) }
  let(:user)    { Identity::User.create!(email: "sam@acme.io", password: "hunter2pw") }

  before { allow(Apartment::Tenant).to receive(:switch).and_yield }

  def headers_for(current_user = user)
    {
      "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: current_user.id.to_s })}",
      "HOST" => "acme.example.com"
    }
  end

  it "returns context for an active member" do
    Identity::Membership.create!(user: user, tenant: tenant, role: :admin, status: :active)

    get "/api/v1/context", headers: headers_for

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["tenant"]["subdomain"]).to eq("acme")
    expect(body["role"]).to eq("admin")
  end

  it "403s when authenticated but not a member of this tenant" do
    get "/api/v1/context", headers: headers_for

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("no_membership")
  end

  it "403s when the membership exists but is not active" do
    Identity::Membership.create!(user: user, tenant: tenant, role: :staff, status: :invited)

    get "/api/v1/context", headers: headers_for

    expect(response).to have_http_status(:forbidden)
  end

  it "401s without an access token" do
    get "/api/v1/context", headers: { "HOST" => "acme.example.com" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "404s on an unknown tenant subdomain" do
    get "/api/v1/context",
        headers: { "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}",
                   "HOST" => "ghost.example.com" }

    expect(response).to have_http_status(:not_found)
  end
end
