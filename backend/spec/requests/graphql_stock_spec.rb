require "rails_helper"

RSpec.describe "GraphQL stock", type: :request do
  let!(:tenant)   { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)     { create(:user) }
  let(:product)   { create(:product) }
  let(:warehouse) { create(:warehouse) }

  before do
    allow(Apartment::Tenant).to receive(:switch).and_yield
    create(:membership, user: admin, tenant: tenant, role: :admin, status: :active)
  end

  def gql(query, variables: {})
    post "/graphql",
         params: { query: query, variables: variables }.to_json,
         headers: {
           "HOST" => "acme.example.com",
           "Content-Type" => "application/json",
           "Authorization" => "Bearer #{Identity::JwtCodec.encode({ sub: admin.id.to_s })}"
         }
    JSON.parse(response.body)
  end

  let(:record_mutation) do
    <<~GQL
      mutation($p: ID!, $w: ID!, $t: MovementTypeEnum!, $d: Int!) {
        recordStockMovement(input: { productId: $p, warehouseId: $w, movementType: $t, quantityDelta: $d }) {
          movement { id movementType quantityDelta }
          userErrors { code message }
        }
      }
    GQL
  end

  it "records a movement and updates the level" do
    body = gql(record_mutation, variables: { p: product.id.to_s, w: warehouse.id.to_s, t: "RECEIPT", d: 12 })

    payload = body.dig("data", "recordStockMovement")
    expect(payload["userErrors"]).to be_empty
    expect(payload.dig("movement", "quantityDelta")).to eq(12)

    levels = gql("{ stockLevels { edges { node { quantityOnHand availableQuantity } } } }")
    node = levels.dig("data", "stockLevels", "edges").first.dig("node")
    expect(node["quantityOnHand"]).to eq(12)
    expect(node["availableQuantity"]).to eq(12)
  end

  it "returns insufficient_stock as a userError" do
    body = gql(record_mutation, variables: { p: product.id.to_s, w: warehouse.id.to_s, t: "SALE", d: -5 })

    payload = body.dig("data", "recordStockMovement")
    expect(payload["movement"]).to be_nil
    expect(payload["userErrors"].first["code"]).to eq("insufficient_stock")
  end

  it "lists the ledger via stockMovements" do
    gql(record_mutation, variables: { p: product.id.to_s, w: warehouse.id.to_s, t: "RECEIPT", d: 4 })

    body = gql("{ stockMovements { edges { node { movementType quantityDelta } } } }")
    nodes = body.dig("data", "stockMovements", "edges").map { |e| e["node"] }
    expect(nodes.first["quantityDelta"]).to eq(4)
  end
end
