require "swagger_helper"

# Warehouse REST CRUD (rswag → OpenAPI). Tenant-scoped: Apartment switch stubbed,
# host pinned to the tenant subdomain, sample admin auth.
RSpec.describe "Warehouses", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }
  let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: admin.id.to_s })}" }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
    host! "acme.example.com"
  end

  path "/api/v1/warehouses" do
    post "Create a warehouse" do
      tags "Warehouses"
      consumes "application/json"
      produces "application/json"
      security [ { bearer_auth: [] } ]
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          warehouse: {
            type: :object,
            properties: {
              name: { type: :string, example: "Main" },
              code: { type: :string, example: "WH-1" },
              address: { type: :object, example: { city: "Austin" } }
            },
            required: %w[name code]
          }
        },
        required: %w[warehouse]
      }

      response "201", "created" do
        let(:payload) { { warehouse: { name: "Main", code: "WH-1", address: { city: "Austin" } } } }
        run_test!
      end

      response "409", "duplicate code (code_taken)" do
        before { create(:warehouse, code: "WH-1") }
        let(:payload) { { warehouse: { name: "Dup", code: "wh-1" } } }
        run_test!
      end

      response "403", "a role that can't manage inventory (purchasing)" do
        let(:buyer) { create(:user) }
        let(:Authorization) do
          create(:membership, user: buyer, tenant: tenant, role: :purchasing, status: :active)
          "Bearer #{Identity::JwtCodec.encode({ sub: buyer.id.to_s })}"
        end
        let(:payload) { { warehouse: { name: "X", code: "X-1" } } }
        run_test!
      end
    end
  end

  path "/api/v1/warehouses/{id}" do
    parameter name: :id, in: :path, type: :string

    get "Show a warehouse" do
      tags "Warehouses"
      produces "application/json"
      security [ { bearer_auth: [] } ]

      response "200", "found" do
        let(:id) { create(:warehouse, name: "Depot").id.to_s }
        run_test!
      end

      response "404", "soft-deleted or missing" do
        let(:id) { create(:warehouse).tap(&:soft_delete!).id.to_s }
        run_test!
      end
    end

    delete "Soft-delete a warehouse" do
      tags "Warehouses"
      security [ { bearer_auth: [] } ]

      response "204", "deleted" do
        let(:id) { create(:warehouse).id.to_s }
        run_test!
      end
    end
  end
end
