# frozen_string_literal: true

module Api
  module V1
    # Base for TENANT-SCOPED API endpoints (products, warehouses, stock, … in
    # Milestone 4). Stacks the full request pipeline:
    #   1. within_tenant  — resolve tenant from subdomain + switch schema (around)
    #   2. authenticate_user! — decode the access token -> Current.user
    #   3. require_membership! — active membership in this tenant -> Current.membership
    #   4. verify_authorized  — fail closed: every action MUST call `authorize`
    #
    # The apex auth endpoints (AuthController, MeController) inherit BaseController
    # directly and do NOT get this stack.
    class TenantBaseController < BaseController
      include TenantResolution
      include TenantMembership

      before_action :authenticate_user!
      before_action :require_membership!

      # Fail closed: if an action forgets to call `authorize`, this raises
      # (surfacing the bug) rather than silently allowing the request.
      after_action :verify_authorized
    end
  end
end
