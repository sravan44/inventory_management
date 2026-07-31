# frozen_string_literal: true

module Api
  module V1
    # Base for all /api/v1 controllers. Holds cross-cutting concerns shared by the
    # auth endpoints now; the full standard error envelope + tenant/authorization
    # wiring expands here in Milestone 3 (commit 3.1).
    class BaseController < ApplicationController
      include Authenticatable

      rescue_from ActionController::ParameterMissing do |error|
        render json: {
          error: { code: "parameter_missing", message: error.message }
        }, status: :bad_request
      end

      private

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
