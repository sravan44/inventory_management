require "swagger_helper"

RSpec.describe "Tenants", type: :request do
  path "/api/v1/tenants" do
    post "Create a tenant (async provisioning)" do
      tags "Tenants"
      consumes "application/json"
      produces "application/json"
      security [ { bearer_auth: [] } ]
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          tenant: {
            type: :object,
            properties: {
              name: { type: :string, example: "Acme" },
              subdomain: { type: :string, example: "acme" }
            },
            required: %w[name subdomain]
          }
        },
        required: %w[tenant]
      }

      response "202", "created; provisioning enqueued; creator is admin" do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}" }
        let(:payload) { { tenant: { name: "Acme", subdomain: "acme-#{SecureRandom.hex(3)}" } } }
        run_test!
      end

      response "401", "not authenticated" do
        let(:Authorization) { "Bearer not.a.jwt" }
        let(:payload) { { tenant: { name: "Acme", subdomain: "acme" } } }
        run_test!
      end
    end
  end
end
