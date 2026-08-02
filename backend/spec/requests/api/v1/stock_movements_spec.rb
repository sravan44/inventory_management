require "swagger_helper"

# Record a stock movement over REST (rswag → OpenAPI). Tenant-scoped: Apartment
# switch stubbed, host pinned, sample admin auth.
RSpec.describe "Stock movements", type: :request do
  let!(:tenant)    { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)      { create(:user) }
  let(:product)    { create(:product) }
  let(:warehouse)  { create(:warehouse) }
  let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: admin.id.to_s })}" }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
    host! "acme.example.com"
  end

  path "/api/v1/stock_movements" do
    post "Record a stock movement" do
      tags "Stock"
      consumes "application/json"
      produces "application/json"
      security [ { bearer_auth: [] } ]
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          stock_movement: {
            type: :object,
            properties: {
              product_id: { type: :string },
              warehouse_id: { type: :string },
              movement_type: { type: :string, enum: %w[receipt adjustment transfer_in transfer_out sale] },
              quantity_delta: { type: :integer }
            },
            required: %w[product_id warehouse_id movement_type quantity_delta]
          }
        },
        required: %w[stock_movement]
      }

      response "201", "recorded (ledger row + level updated)" do
        let(:payload) do
          { stock_movement: { product_id: product.id.to_s, warehouse_id: warehouse.id.to_s,
                              movement_type: "receipt", quantity_delta: 10 } }
        end
        run_test!
      end

      response "409", "insufficient stock" do
        let(:payload) do
          { stock_movement: { product_id: product.id.to_s, warehouse_id: warehouse.id.to_s,
                              movement_type: "sale", quantity_delta: -5 } }
        end
        run_test! do |response|
          expect(JSON.parse(response.body).dig("error", "code")).to eq("insufficient_stock")
        end
      end
    end
  end
end
