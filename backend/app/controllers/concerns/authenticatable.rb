# frozen_string_literal: true

# Mixed into controllers that require a valid access token. Reads the Bearer JWT,
# decodes it via JwtCodec, loads the user into Current.user, and 401s otherwise.
#
# Runs independently of tenant resolution: the token identifies the user
# globally; tenant context (and the membership check) is a separate concern
# (ADR-0004), added for tenant-scoped controllers in commit 2.6.
module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    payload = Identity::JwtCodec.decode(bearer_token)
    Current.user = Identity::User.kept.find(payload["sub"])
  rescue Identity::JwtCodec::InvalidToken, ActiveRecord::RecordNotFound
    render_unauthorized
  end

  def current_user
    Current.user
  end

  def bearer_token
    # "Authorization: Bearer <token>" -> "<token>" (nil-safe: missing header
    # yields nil, which JwtCodec.decode rejects as InvalidToken).
    request.headers["Authorization"].to_s.split.last
  end

  def render_unauthorized
    response.set_header("WWW-Authenticate", 'Bearer error="invalid_token"')
    render json: {
      error: { code: "unauthorized", message: "Invalid or missing access token." }
    }, status: :unauthorized
  end
end
