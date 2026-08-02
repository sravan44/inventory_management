require "rails_helper"

RSpec.describe "GraphQL warehouses", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", status: :active) }
  let(:admin)   { create(:user) }

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

  it "lists the tenant's warehouses as a connection" do
    create(:warehouse, code: "A", name: "Alpha")
    create(:warehouse, code: "B", name: "Beta")

    body = gql("{ warehouses(first: 10) { edges { node { code name active } } } }")

    codes = body.dig("data", "warehouses", "edges").map { |e| e.dig("node", "code") }
    expect(codes).to contain_exactly("A", "B")
  end
end
