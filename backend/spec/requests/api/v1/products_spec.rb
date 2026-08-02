require "swagger_helper"

# Product REST CRUD — rswag DSL: these run as real tests AND generate the OpenAPI
# docs (ADR-0012). Tenant-scoped, so we stub Apartment's schema switch and pin the
# request host to a tenant subdomain via host!. Sample auth: an admin member of
# "acme"; individual responses override Authorization to exercise the policies.
RSpec.describe "Products", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }
  let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: admin.id.to_s })}" }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
    host! "acme.example.com"
  end

  path "/api/v1/products" do
    post "Create a product" do
      tags "Products"
      consumes "application/json"
      produces "application/json"
      security [ { bearer_auth: [] } ]
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              sku: { type: :string, example: "ABC-1" },
              name: { type: :string, example: "Widget" },
              description: { type: :string },
              unit_of_measure: { type: :string, example: "each" }
            },
            required: %w[sku name]
          }
        },
        required: %w[product]
      }

      response "201", "created (admin/staff, or an API key with that role)" do
        let(:payload) { { product: { sku: "ABC-1", name: "Widget", unit_of_measure: "each" } } }
        run_test!
      end

      response "409", "duplicate SKU (sku_taken)" do
        before { create(:product, sku: "ABC-1") }
        let(:payload) { { product: { sku: "abc-1", name: "Dup" } } }
        run_test!
      end

      response "422", "validation failed" do
        let(:payload) { { product: { sku: "" } } }
        run_test!
      end

      response "403", "a role that can't manage inventory (purchasing)" do
        let(:buyer) { create(:user) }
        let(:Authorization) do
          create(:membership, user: buyer, tenant: tenant, role: :purchasing, status: :active)
          "Bearer #{Identity::JwtCodec.encode({ sub: buyer.id.to_s })}"
        end
        let(:payload) { { product: { sku: "X-1", name: "Nope" } } }
        run_test!
      end
    end
  end

  path "/api/v1/products/{id}" do
    parameter name: :id, in: :path, type: :string

    get "Show a product" do
      tags "Products"
      produces "application/json"
      security [ { bearer_auth: [] } ]

      response "200", "found" do
        let(:id) { create(:product, name: "Shown").id.to_s }
        run_test!
      end

      response "404", "soft-deleted or missing" do
        let(:id) { create(:product).tap(&:soft_delete!).id.to_s }
        run_test!
      end
    end

    patch "Update a product" do
      tags "Products"
      consumes "application/json"
      produces "application/json"
      security [ { bearer_auth: [] } ]
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              unit_of_measure: { type: :string }
            }
          }
        },
        required: %w[product]
      }

      response "200", "updated" do
        let(:id) { create(:product, name: "Old").id.to_s }
        let(:payload) { { product: { name: "New" } } }
        run_test!
      end
    end

    delete "Soft-delete a product" do
      tags "Products"
      security [ { bearer_auth: [] } ]

      response "204", "deleted" do
        let(:id) { create(:product).id.to_s }
        run_test!
      end
    end
  end
end
