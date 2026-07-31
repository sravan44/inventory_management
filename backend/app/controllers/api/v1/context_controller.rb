# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/context (on a tenant subdomain) — "who am I in THIS tenant".
    # A demonstrator that exercises the full tenant-scoped stack: resolution +
    # auth + membership gate. Returns the user, tenant, and this tenant's role.
    class ContextController < TenantBaseController
      # This isn't a Pundit-authorized resource action, so skip the fail-closed
      # check here. Real resource controllers (Milestone 4) will NOT skip it —
      # every action must `authorize`.
      skip_after_action :verify_authorized, only: :show

      def show
        render json: {
          user: user_json(Current.user),
          tenant: {
            id: Current.tenant.id.to_s,
            name: Current.tenant.name,
            subdomain: Current.tenant.subdomain
          },
          role: Current.membership.role
        }
      end
    end
  end
end
