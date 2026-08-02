require "rails_helper"

# Confirms state-changing operations emit audit events (they enqueue the emit job).
RSpec.describe "Audit instrumentation", type: :request do
  include ActiveJob::TestHelper

  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  def admin_headers
    {
      "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: admin.id.to_s })}",
      "HOST" => "acme.example.com"
    }
  end

  it "emits product.created when a product is created" do
    expect do
      post "/api/v1/products",
           params: { product: { sku: "ABC-1", name: "Widget" } },
           headers: admin_headers
    end.to have_enqueued_job(Audit::EmitActivityLogJob)

    attrs = enqueued_jobs.last["arguments"].first
    expect(attrs["action"]).to eq("product.created")
    expect(attrs["tenant_id"]).to eq(tenant.id)
    expect(attrs["actor_type"]).to eq("Identity::User")
  end

  it "does NOT emit when the create fails validation" do
    expect do
      post "/api/v1/products", params: { product: { sku: "" } }, headers: admin_headers
    end.not_to have_enqueued_job(Audit::EmitActivityLogJob)
  end
end
