require "rails_helper"

module Audit
  RSpec.describe Logger do
    include ActiveJob::TestHelper

    it "enqueues the emit job (never blocks the caller)" do
      expect { described_class.log(action: "product.created") }
        .to have_enqueued_job(Audit::EmitActivityLogJob)
    end

    it "captures request context from Current" do
      tenant = create(:tenant)
      user = create(:user)
      Current.tenant = tenant
      Current.user = user

      described_class.log(action: "product.created")

      job = enqueued_jobs.last
      attrs = job["arguments"].first
      expect(attrs["tenant_id"]).to eq(tenant.id)
      expect(attrs["actor_type"]).to eq("Identity::User")
      expect(attrs["action"]).to eq("product.created")
    ensure
      Current.reset
    end
  end
end
