# frozen_string_literal: true

# The single GraphQL endpoint (POST /graphql), served on a tenant subdomain.
# FIRST-PARTY ONLY (ADR-0009): it authenticates with the user JWT and requires an
# active membership — it deliberately does NOT use ActorAuthentication, so an
# Api-Key is rejected (the raw key fails JWT decode -> 401). API keys are REST-only.
class GraphqlController < ApplicationController
  include ErrorResponses      # standard error envelope + render_error
  include Authenticatable     # Bearer JWT -> Current.user (rejects non-Bearer)
  include TenantResolution    # subdomain -> Current.tenant + schema switch
  include TenantMembership    # active membership -> Current.membership, else 403

  before_action :authenticate_user!
  before_action :require_membership!

  def execute
    result = InventoryManagementSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: {
        current_user: Current.user,
        current_membership: Current.membership,
        current_tenant: Current.tenant
      }
    )
    render json: result
  end

  private

  # GraphQL variables arrive as a JSON string, a hash, params, or nil.
  def prepare_variables(raw)
    case raw
    when String then raw.present? ? JSON.parse(raw) : {}
    when Hash then raw
    when ActionController::Parameters then raw.to_unsafe_hash
    when nil then {}
    else raise ArgumentError, "Unexpected parameter: #{raw}"
    end
  end
end
