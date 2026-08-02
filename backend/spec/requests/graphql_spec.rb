require "rails_helper"

# GraphQL is first-party (user JWT) + tenant-scoped. Apartment switch stubbed.
RSpec.describe "GraphQL", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:user)    { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: user, tenant: tenant, role: :admin, status: :active)
  end

  def bearer(u)
    "Bearer #{Identity::JwtCodec.encode({ sub: u.id.to_s })}"
  end

  it "resolves viewer for an authenticated member" do
    post "/graphql",
         params: { query: "{ viewer { email role tenantSubdomain } }" },
         headers: { "HOST" => "acme.example.com", "Authorization" => bearer(user) }

    expect(response).to have_http_status(:ok)
    viewer = JSON.parse(response.body).dig("data", "viewer")
    expect(viewer["email"]).to eq(user.email)
    expect(viewer["role"]).to eq("admin")
    expect(viewer["tenantSubdomain"]).to eq("acme")
  end

  it "runs the ping mutation" do
    post "/graphql",
         params: { query: "mutation { ping }" },
         headers: { "HOST" => "acme.example.com", "Authorization" => bearer(user) }

    expect(JSON.parse(response.body).dig("data", "ping")).to eq("pong")
  end

  it "401s without a token" do
    post "/graphql",
         params: { query: "{ viewer { email } }" },
         headers: { "HOST" => "acme.example.com" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "403s when authenticated but not a member" do
    outsider = create(:user)
    post "/graphql",
         params: { query: "{ viewer { email } }" },
         headers: { "HOST" => "acme.example.com", "Authorization" => bearer(outsider) }

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an Api-Key credential (GraphQL is user-JWT only)" do
    _record, raw = Identity::ApiKey.issue(tenant: tenant, name: "k")
    post "/graphql",
         params: { query: "{ viewer { email } }" },
         headers: { "HOST" => "acme.example.com", "Authorization" => "Api-Key #{raw}" }

    expect(response).to have_http_status(:unauthorized)
  end
end
