# frozen_string_literal: true

module Identity
  # Runs tenant provisioning OFF the request thread. Creating a schema + loading
  # structure can take a moment; the API returns 202 Accepted immediately
  # (Milestone 3) and this job does the work in the background.
  #
  # We pass the tenant *id* (not the record). ActiveJob serializes arguments to
  # the queue backend; passing a bare id is simplest and avoids stale in-memory
  # state — the job refetches the current row.
  class ProvisionTenantJob < ApplicationJob
    queue_as :default

    def perform(tenant_id)
      tenant = Identity::Tenant.find(tenant_id)
      TenantProvisioningService.call(tenant)
    end
  end
end
