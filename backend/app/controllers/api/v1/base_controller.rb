# frozen_string_literal: true

module Api
  module V1
    # Base for all /api/v1 controllers.
    #
    # Versioning (API_DESIGN.md): the version lives in the URL (`/api/v1`).
    # Additive changes stay in v1; a breaking change introduces `/api/v2` with a
    # published sunset window — the two run side by side during deprecation.
    class BaseController < ApplicationController
      include ErrorResponses          # the standard error envelope + exception mapping
      include Authenticatable
      include Pundit::Authorization

      private

      # Pundit authorizes against the current user (tenant/role come from
      # Current.membership inside the policies).
      def pundit_user
        Current.user
      end

      def user_json(user)
        {
          id: user.id.to_s,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name
        }
      end

      def memberships_json(user)
        user.memberships.includes(:tenant).map do |membership|
          {
            role: membership.role,
            status: membership.status,
            tenant: {
              id: membership.tenant.id.to_s,
              name: membership.tenant.name,
              subdomain: membership.tenant.subdomain
            }
          }
        end
      end
    end
  end
end
