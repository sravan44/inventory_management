require "rails_helper"

# Drives the resolver through real HTTP with different Host headers.
# NOTE: for these custom hosts to be accepted, test env must not block them —
# see config/environments/test.rb `config.hosts.clear` (explained in the
# walkthrough).
RSpec.describe "Tenant resolution", type: :request do
  let!(:tenant) do
    Identity::Tenant.create!(name: "Acme", subdomain: "acme", status: :active)
  end

  # This spec exercises the RESOLUTION logic (subdomain -> tenant, 404/403), not
  # Apartment's schema machinery (covered by the provisioning specs). Stub the
  # switch to a no-op so we don't need a real Postgres schema to exist here.
  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
  end

  def host_for(subdomain)
    "#{subdomain}.example.com"
  end

  it "resolves an active tenant from the subdomain" do
    get "/current_tenant", headers: { "HOST" => host_for("acme") }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "subdomain")).to eq("acme")
  end

  it "returns 404 for an unknown subdomain" do
    get "/current_tenant", headers: { "HOST" => host_for("does-not-exist") }

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("unknown_tenant")
  end

  it "returns 403 for a suspended (non-active) tenant" do
    tenant.update!(status: :suspended)

    get "/current_tenant", headers: { "HOST" => host_for("acme") }

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("tenant_unavailable")
  end

  it "returns 404 on the apex host (no subdomain)" do
    get "/current_tenant", headers: { "HOST" => "example.com" }

    expect(response).to have_http_status(:not_found)
  end

  it "does not resolve a soft-deleted tenant" do
    tenant.soft_delete!

    get "/current_tenant", headers: { "HOST" => host_for("acme") }

    expect(response).to have_http_status(:not_found)
  end
end
