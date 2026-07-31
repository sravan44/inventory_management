# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/me — the current user plus their memberships. The SPA uses the
    # memberships (each with its tenant subdomain) to route into the right tenant.
    class MeController < BaseController
      before_action :authenticate_user!

      def show
        render json: {
          user: user_json(current_user),
          memberships: memberships_json(current_user)
        }
      end
    end
  end
end
