# frozen_string_literal: true

# Dual authentication for tenant-scoped endpoints (ADR-0009/0010). Accepts EITHER:
#   Authorization: Bearer <jwt>    -> a User; must have an active membership here
#   Authorization: Api-Key <key>   -> an ApiKey; must belong to this tenant
# and normalizes the result into Current (user+membership, or api_key). Runs after
# tenant resolution, so Current.tenant is already set.
#
# GraphQL (Milestone 4) will NOT use this — it's first-party only and accepts the
# user JWT exclusively (ADR-0009). API keys are a REST-only credential.
module ActorAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_actor!
    scheme, credential = request.headers["Authorization"].to_s.split(" ", 2)

    case scheme
    when "Bearer"  then authenticate_user_actor!(credential)
    when "Api-Key" then authenticate_api_key_actor!(credential)
    else render_unauthorized
    end
  end

  # JWT identifies the user; an ACTIVE membership in the resolved tenant is the
  # authorization to act here.
  def authenticate_user_actor!(token)
    payload = Identity::JwtCodec.decode(token.to_s)
    user = Identity::User.kept.find(payload["sub"])
    membership = Identity::Membership.active.find_by(user: user, tenant: Current.tenant)

    return render_error(:forbidden, "no_membership", "You don't have access to this tenant.") if membership.nil?

    Current.user = user
    Current.membership = membership
  rescue Identity::JwtCodec::InvalidToken, ActiveRecord::RecordNotFound
    render_unauthorized
  end

  # The API key IS the grant; it must belong to the tenant on the subdomain.
  def authenticate_api_key_actor!(raw)
    key = Identity::ApiKey.find_active(raw.to_s)

    return render_unauthorized if key.nil?

    if key.tenant_id != Current.tenant&.id
      return render_error(:forbidden, "forbidden", "This API key is not valid for this tenant.")
    end

    key.mark_used!
    Current.api_key = key
  end
end
