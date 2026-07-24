# frozen_string_literal: true

# Minimal tenant-scoped endpoint: echoes the tenant resolved from the subdomain.
# It's the first real consumer of TenantResolution and doubles as a sanity check
# ("is my subdomain wiring correct?"). Later milestones add the real resource
# controllers under /api/v1, all inheriting the same TenantScopedController.
class CurrentTenantController < TenantScopedController
  def show
    render json: {
      data: {
        id: Current.tenant.id.to_s,
        name: Current.tenant.name,
        subdomain: Current.tenant.subdomain,
        status: Current.tenant.status
      }
    }
  end
end
