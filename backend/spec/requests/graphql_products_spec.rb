require "rails_helper"

# Product GraphQL: list query (connection) + setProductActive mutation.
# Requests are sent as JSON so variable types (e.g. Boolean) are preserved —
# form-encoding would turn `active: false` into the string "false" and break
# GraphQL's Boolean coercion.
RSpec.describe "GraphQL products", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  def gql(query, user: admin, variables: {})
    post "/graphql",
         params: { query: query, variables: variables }.to_json,
         headers: {
           "HOST" => "acme.example.com",
           "Content-Type" => "application/json",
           "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: user.id.to_s })}"
         }
    JSON.parse(response.body)
  end

  describe "products query" do
    it "returns the tenant's products as a connection" do
      create(:product, sku: "A-1", name: "Alpha")
      create(:product, sku: "B-1", name: "Beta")

      body = gql("{ products(first: 10) { edges { node { sku name active } } pageInfo { hasNextPage } } }")

      skus = body.dig("data", "products", "edges").map { |e| e.dig("node", "sku") }
      expect(skus).to contain_exactly("A-1", "B-1")
    end

    it "filters by active" do
      create(:product, sku: "ON-1", active: true)
      create(:product, sku: "OFF-1", active: true).update!(active: false)

      body = gql(
        "query($active: Boolean) { products(first: 50, active: $active) { edges { node { sku } } } }",
        variables: { active: false }
      )

      skus = body.dig("data", "products", "edges").map { |e| e.dig("node", "sku") }
      expect(skus).to eq([ "OFF-1" ])
    end
  end

  describe "setProductActive mutation" do
    let(:mutation) do
      <<~GQL
        mutation($id: ID!, $active: Boolean!) {
          setProductActive(input: { id: $id, active: $active }) {
            product { id active }
            userErrors { code message }
          }
        }
      GQL
    end

    it "deactivates a product" do
      product = create(:product, active: true)
      body = gql(mutation, variables: { id: product.id.to_s, active: false })

      payload = body.dig("data", "setProductActive")
      expect(payload.dig("product", "active")).to be(false)
      expect(payload["userErrors"]).to be_empty
      expect(product.reload.active).to be(false)
    end

    it "returns a not_found userError for a missing product" do
      body = gql(mutation, variables: { id: "0", active: false })

      payload = body.dig("data", "setProductActive")
      expect(payload["product"]).to be_nil
      expect(payload["userErrors"].first["code"]).to eq("not_found")
    end

    it "denies a role that can't manage inventory (top-level error)" do
      buyer = create(:user)
      create(:membership, user: buyer, tenant: tenant, role: :purchasing, status: :active)
      product = create(:product)

      body = gql(mutation, user: buyer, variables: { id: product.id.to_s, active: false })

      expect(body["errors"]).to be_present
      expect(product.reload.active).to be(true)
    end
  end
end
