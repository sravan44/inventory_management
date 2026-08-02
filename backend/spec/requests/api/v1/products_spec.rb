require "rails_helper"

# Product REST CRUD. Tenant-scoped; Apartment switch stubbed. Exercises both the
# user path and the API-key path (the first endpoint that honors keys).
RSpec.describe "Api::V1::Products", type: :request do
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

  describe "POST /api/v1/products" do
    it "creates a product (201)" do
      post "/api/v1/products",
           params: { product: { sku: "ABC-1", name: "Widget", unit_of_measure: "each" } },
           headers: user_headers(admin)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["sku"]).to eq("ABC-1")
      expect(body["active"]).to be(true)
    end

    it "returns 409 sku_taken on a duplicate SKU" do
      create(:product, sku: "ABC-1")

      post "/api/v1/products",
           params: { product: { sku: "abc-1", name: "Dup" } },
           headers: user_headers(admin)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("sku_taken")
    end

    it "422 when required fields are missing" do
      post "/api/v1/products",
           params: { product: { sku: "" } },
           headers: user_headers(admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "403 for a role that can't manage inventory (purchasing)" do
      buyer = create(:user)
      create(:membership, user: buyer, tenant: tenant, role: :purchasing, status: :active)

      post "/api/v1/products",
           params: { product: { sku: "X-1", name: "N" } },
           headers: user_headers(buyer)

      expect(response).to have_http_status(:forbidden)
    end

    it "allows an API key with a manager role to create (dual auth)" do
      _record, raw = Identity::ApiKey.issue(tenant: tenant, name: "CI", role: :staff)

      post "/api/v1/products",
           params: { product: { sku: "K-1", name: "Via key" } },
           headers: { "Authorization" => "Api-Key #{raw}", "HOST" => "acme.example.com" }

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /api/v1/products/:id" do
    it "shows a product" do
      product = create(:product, sku: "SHOW-1", name: "Shown")
      get "/api/v1/products/#{product.id}", headers: user_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq("Shown")
    end

    it "404 for a soft-deleted product" do
      product = create(:product)
      product.soft_delete!
      get "/api/v1/products/#{product.id}", headers: user_headers(admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/products/:id" do
    it "updates a product" do
      product = create(:product, name: "Old")
      patch "/api/v1/products/#{product.id}",
            params: { product: { name: "New" } },
            headers: user_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(product.reload.name).to eq("New")
    end
  end

  describe "DELETE /api/v1/products/:id" do
    it "soft-deletes a product (204)" do
      product = create(:product)
      delete "/api/v1/products/#{product.id}", headers: user_headers(admin)
      expect(response).to have_http_status(:no_content)
      expect(product.reload.deleted?).to be(true)
    end
  end
end
