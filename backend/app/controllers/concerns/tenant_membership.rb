# frozen_string_literal: true

# The authorization boundary between "who you are" and "what you can do HERE".
# Requires an ACTIVE membership for Current.user in Current.tenant, and exposes it
# as Current.membership (whose role the policies read). Runs after tenant
# resolution and authentication.
#
# No membership -> 403 (you're authenticated, the tenant exists, but you have no
# access to it). This is distinct from 404 (tenant/subdomain doesn't exist) and
# 401 (not authenticated).
module TenantMembership
  extend ActiveSupport::Concern

  private

  def require_membership!
    membership = Identity::Membership.active.find_by(
      user: Current.user, tenant: Current.tenant
    )

    if membership.nil?
      # render_error comes from ErrorResponses (Api::V1::BaseController).
      return render_error(:forbidden, "no_membership", "You don't have access to this tenant.")
    end

    Current.membership = membership
  end
end
