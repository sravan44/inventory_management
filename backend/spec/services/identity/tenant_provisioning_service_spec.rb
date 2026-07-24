require "rails_helper"

module Identity
  RSpec.describe TenantProvisioningService do
    let(:tenant) { Tenant.create!(name: "Acme", subdomain: "acme") }

    # Integration test: it creates a REAL Postgres schema in the test DB, so we
    # clean it up afterward regardless of pass/fail.
    after { Apartment::Tenant.drop(tenant.schema_name) rescue nil }

    def existing_schema_names
      ActiveRecord::Base.connection
        .execute("SELECT schema_name FROM information_schema.schemata")
        .map { |row| row["schema_name"] }
    end

    it "creates the tenant's Postgres schema" do
      described_class.call(tenant)
      expect(existing_schema_names).to include(tenant.schema_name)
    end

    it "activates the tenant" do
      described_class.call(tenant)
      expect(tenant.reload).to be_active
    end

    it "is idempotent when the schema already exists" do
      described_class.call(tenant)
      expect { described_class.call(tenant) }.not_to raise_error
      expect(tenant.reload).to be_active
    end
  end
end
