require "rails_helper"

module Identity
  RSpec.describe TenantProvisioningService do
    # Real DDL, not rolled back: re-running Apartment::Tenant.create against an
    # existing schema makes ros-apartment issue a raw `ROLLBACK;` (see
    # postgresql_adapter.rb#create_tenant_command) rather than releasing a
    # savepoint. Under the default transactional-fixture wrapper that ROLLBACK
    # unwinds the *whole* example's transaction -- including the `tenant` row
    # created below -- so `tenant.reload` blows up with RecordNotFound in the
    # "idempotent" example. Disable transactional fixtures here and clean up
    # manually instead (per the note in rails_helper.rb).
    self.use_transactional_tests = false

    let(:tenant) { Tenant.create!(name: "Acme", subdomain: "acme") }

    # Integration test: it creates a REAL Postgres schema in the test DB, so we
    # clean it up afterward regardless of pass/fail.
    after do
      Apartment::Tenant.drop(tenant.schema_name) rescue nil
      tenant.destroy
    end

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
