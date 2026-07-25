require "rails_helper"

# Config-level spec: proves Apartment is wired the way ADR-0002 requires,
# without needing any tenant to exist yet. Cheap guard against someone later
# flipping use_schemas off or changing the default schema by accident.
RSpec.describe "Apartment configuration" do
  it "uses PostgreSQL schemas (schema-per-tenant, not database-per-tenant)" do
    expect(Apartment.use_schemas).to be(true)
  end

  it "falls back to the public tenant when none is active" do
    expect(Apartment.default_tenant).to eq("public")
  end

  it "sources tenant schemas from the Tenant table (empty when none exist)" do
    # Apartment.tenant_names evaluates the configured proc and returns the array.
    expect(Apartment.tenant_names).to eq([])
  end

  it "adds a tenant schema name once a Tenant is created" do
    tenant = Identity::Tenant.create!(name: "Acme", subdomain: "acme")
    expect(Apartment.tenant_names).to include(tenant.schema_name)
  end

  it "excludes the global Tenant model from schema switching (lives in public)" do
    expect(Apartment.excluded_models).to include("Identity::Tenant")
  end
end
