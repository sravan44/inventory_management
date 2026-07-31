# frozen_string_literal: true

module Identity
  # Owns the authentication workflows (ADR-0005): logging in, and exchanging a
  # refresh token for a fresh access token with ROTATION + REUSE DETECTION.
  #
  # Rotation: every refresh consumes (revokes) the presented refresh token and
  # issues a brand-new one. A refresh token is therefore single-use.
  #
  # Reuse detection: if a client presents a refresh token that was already
  # rotated away (revoked), that's a strong theft signal — the same token is in
  # two hands. We respond by revoking ALL of that user's tokens, forcing a fresh
  # login everywhere.
  class AuthenticationService
    class InvalidCredentials < StandardError; end
    class InvalidRefreshToken < StandardError; end

    Result = Struct.new(:user, :access_token, :refresh_token, keyword_init: true)

    # Verify email + password, issue a token pair.
    def self.authenticate(email:, password:)
      user = Identity::User.kept.find_by(email: email.to_s.strip.downcase)
      raise InvalidCredentials unless user&.authenticate(password)

      issue_for(user)
    end

    # Exchange a refresh token for a new pair.
    def self.refresh(raw_refresh_token)
      token = Identity::RefreshToken.find_active(raw_refresh_token)

      if token.nil?
        handle_possible_reuse(raw_refresh_token)
        raise InvalidRefreshToken
      end

      token.revoke!            # single-use: consume the presented token
      issue_for(token.user)
    end

    # Log out this session (revoke one refresh token).
    def self.revoke(raw_refresh_token)
      Identity::RefreshToken.find_active(raw_refresh_token)&.revoke!
    end

    # Log out everywhere (revoke all of a user's active refresh tokens).
    def self.revoke_all(user)
      user.refresh_tokens.where(revoked_at: nil).find_each(&:revoke!)
    end

    # Issue a fresh access + refresh pair for an already-authenticated user
    # (used by login, refresh, and registration auto-login).
    def self.issue_for(user)
      _record, raw_refresh = Identity::RefreshToken.issue(user)
      access = Identity::JwtCodec.encode({ sub: user.id.to_s })
      Result.new(user: user, access_token: access, refresh_token: raw_refresh)
    end

    # If the presented (non-active) token matches a KNOWN revoked token, treat it
    # as reuse of a rotated token — likely stolen — and revoke everything the
    # user has.
    def self.handle_possible_reuse(raw)
      digest = Identity::RefreshToken.digest(raw)
      known = Identity::RefreshToken.find_by(token_digest: digest)
      return if known.nil?

      revoke_all(known.user)
    end
    private_class_method :handle_possible_reuse
  end
end
