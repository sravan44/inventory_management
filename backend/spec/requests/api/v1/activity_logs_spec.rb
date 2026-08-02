require "rails_helper"

# Day-wise audit-log browsing (admin only). Tenant-scoped; Apartment switch and the
# store are stubbed/seeded so no Mongo is needed.
RSpec.describe "Api::V1::ActivityLogs", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    Audit::ActivityLogStore.reset!
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  after { Audit::ActivityLogStore.reset! }

  def headers_for(user)
    {
      "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}",
      "HOST" => "acme.example.com"
    }
  end

  it "returns a day's logs for an admin" do
    Audit::ActivityLogStore.current.insert(
      "1-0",
      { "action" => "product.created", "tenant_id" => tenant.id.to_s,
        "occurred_at" => "2026-07-25T10:00:00Z", "metadata" => { "sku" => "A" } }
    )

    get "/api/v1/activity_logs", params: { date: "2026-07-25" }, headers: headers_for(admin)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["date"]).to eq("2026-07-25")
    expect(body["count"]).to eq(1)
    expect(body["logs"].first["action"]).to eq("product.created")
  end

  it "403 for a non-admin member" do
    staff = create(:user)
    create(:membership, user: staff, tenant: tenant, role: :staff, status: :active)

    get "/api/v1/activity_logs", headers: headers_for(staff)
    expect(response).to have_http_status(:forbidden)
  end

  it "summarizes counts per day" do
    Audit::ActivityLogStore.current.insert(
      "1-0", { "action" => "a", "tenant_id" => tenant.id.to_s, "occurred_at" => "2026-07-25T10:00:00Z", "metadata" => {} }
    )

    get "/api/v1/activity_logs/summary", headers: headers_for(admin)

    expect(response).to have_http_status(:ok)
    days = JSON.parse(response.body)["days"]
    expect(days).to include({ "day" => "2026-07-25", "count" => 1 })
  end
end
