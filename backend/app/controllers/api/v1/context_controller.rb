# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/context (tenant subdomain) — "who am I in THIS tenant". Exercises
    # the full tenant-scoped stack and works for BOTH actor types (user or api_key).
    class ContextController < TenantBaseController
      skip_after_action :verify_authorized, only: :show

      def show
        render json: {
          actor_type: Current.user ? "user" : "api_key",
          user: (user_json(Current.user) if Current.user),
          api_key: api_key_summary,
          tenant: {
            id: Current.tenant.id.to_s,
            name: Current.tenant.name,
            subdomain: Current.tenant.subdomain
          },
          role: Current.role
        }
      end

      private

      def api_key_summary
        return nil unless Current.api_key

        { id: Current.api_key.id.to_s, name: Current.api_key.name }
      end
    end
  end
end
