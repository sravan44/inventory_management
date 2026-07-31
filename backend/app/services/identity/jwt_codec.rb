# frozen_string_literal: true

module Identity
  # Thin wrapper around the `jwt` gem (ADR-0005). Isolating encode/decode here
  # means the rest of the app never touches the JWT library directly — if we ever
  # swap libraries or change the algorithm, only this file changes (DIP).
  class JwtCodec
    ALGORITHM = "HS256"
    DEFAULT_TTL = 15.minutes

    class InvalidToken < StandardError; end

    # Encode a payload into a signed JWT with `exp` (expiry) and `iat` claims.
    def self.encode(payload, ttl: DEFAULT_TTL)
      claims = payload.merge(
        exp: (Time.current + ttl).to_i,
        iat: Time.current.to_i
      )
      JWT.encode(claims, secret, ALGORITHM)
    end

    # Decode + verify (signature and expiry). Raises InvalidToken on any problem,
    # so callers rescue ONE error type rather than the jwt gem's several.
    def self.decode(token)
      payload, = JWT.decode(token, secret, true, { algorithm: ALGORITHM })
      payload
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end

    # HS256 signing key. Prefer a dedicated secret; fall back to Rails'
    # secret_key_base so dev/test work out of the box.
    def self.secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end
    private_class_method :secret
  end
end
