# frozen_string_literal: true

require "digest"
require "securerandom"

module Identity
  # A long-lived, revocable credential used to mint short-lived JWT access tokens
  # (ADR-0005). We store only the SHA-256 DIGEST of the token, never the raw value
  # — so a database leak doesn't hand over usable tokens.
  #
  # Why SHA-256 and not bcrypt (unlike passwords)? The raw token is 384 bits of
  # cryptographic randomness, so there's nothing to brute-force; a fast hash is
  # correct here. bcrypt's deliberate slowness only matters for low-entropy
  # human passwords.
  class RefreshToken < ApplicationRecord
    self.table_name = "refresh_tokens"

    belongs_to :user, class_name: "Identity::User"

    DEFAULT_TTL = 30.days

    # Usable tokens: not revoked and not expired.
    scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

    # Issue a token for a user. Returns [record, raw_token]. The raw token is
    # returned to the caller ONCE (to hand to the client) and never persisted.
    def self.issue(user, ttl: DEFAULT_TTL)
      raw = SecureRandom.urlsafe_base64(48)
      record = create!(
        user: user,
        token_digest: digest(raw),
        expires_at: Time.current + ttl
      )
      [ record, raw ]
    end

    # Look up an ACTIVE token by its raw value (constant work: hash then index
    # lookup). Returns nil if missing, revoked, or expired.
    def self.find_active(raw)
      active.find_by(token_digest: digest(raw))
    end

    def self.digest(raw)
      Digest::SHA256.hexdigest(raw)
    end

    def revoke!
      update!(revoked_at: Time.current) unless revoked?
    end

    def revoked?
      revoked_at.present?
    end

    def expired?
      expires_at <= Time.current
    end

    def active?
      !revoked? && !expired?
    end
  end
end
