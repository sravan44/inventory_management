# frozen_string_literal: true

# Resolves the active tenant from the request SUBDOMAIN and switches the Postgres
# schema for the duration of the action (ADR-0004). Include in any controller
# whose endpoints operate on tenant data.
#
# This is the deliberate reason we did NOT enable Apartment's raw subdomain
# "elevator": we want explicit control over the failure cases (unknown subdomain
# -> 404, non-active tenant -> 403) and to run resolution BEFORE auth (Milestone
# 2), so a bad subdomain is rejected before any credential is even inspected.
module TenantResolution
  extend ActiveSupport::Concern

  included do
    around_action :within_tenant
  end

  private

  def within_tenant
    tenant = Identity::Tenant.kept.find_by(subdomain: request_subdomain)

    if tenant.nil?
      return render_tenant_error(:not_found, "unknown_tenant",
                                 "No tenant matches this subdomain.")
    end

    unless tenant.active?
      return render_tenant_error(:forbidden, "tenant_unavailable",
                                 "This tenant is not currently active.")
    end

    Current.tenant = tenant

    # Block form: switch the schema, run the action, and ALWAYS reset the
    # search_path afterward — even if the action raises. This is the safety net
    # that prevents a leaked schema from bleeding one tenant's data into the next
    # request handled by the same pooled connection.
    Apartment::Tenant.switch(tenant.schema_name) { yield }
  end

  def request_subdomain
    # "" (apex host, no subdomain) becomes nil, so find_by(subdomain: nil) -> 404.
    request.subdomain.to_s.downcase.presence
  end

  def render_tenant_error(status, code, message)
    # Self-contained (this concern is also used by the non-API demonstrator, which
    # doesn't include ErrorResponses). Same envelope shape, incl. request_id.
    render json: {
      error: { code: code, message: message, request_id: request.request_id }
    }, status: status
  end
end
