require "rails_helper"

module Identity
  RSpec.describe ProvisionTenantJob do
    include ActiveJob::TestHelper

    let(:tenant) { Tenant.create!(name: "Acme", subdomain: "acme") }

    after { Apartment::Tenant.drop(tenant.schema_name) rescue nil }

    it "provisions the tenant identified by id" do
      perform_enqueued_jobs { described_class.perform_later(tenant.id) }
      expect(tenant.reload).to be_active
    end

    it "enqueues on the default queue" do
      expect { described_class.perform_later(tenant.id) }
        .to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
