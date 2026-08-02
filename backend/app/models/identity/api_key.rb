# frozen_string_literal: true

require "digest"
require "securerandom"

module Identity
  # A third-party API credential, scoped to one tenant (ADR-0010). Like
  # RefreshToken, we store only the SHA-256 digest; the raw key is returned once.
  # The `ik_` prefix makes leaked keys identifiable in logs/secret scanners.
  class ApiKey < ApplicationRecord
    self.table_name = "api_keys"

    belongs_to :tenant, class_name: "Identity::Tenant"

    enum :role, { admin: 0, staff: 1, purchasing: 2, sales: 3 }, default: :staff

    TOKEN_PREFIX = "ik_"

    # Usable keys: not revoked, and either no expiry or not yet expired.
    scope :active, lambda {
      where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
    }

    # Returns [record, raw_key]. Raw key shown once; only its digest is stored.
    def self.issue(tenant:, name:, role: :staff, expires_at: nil)
      raw = TOKEN_PREFIX + SecureRandom.urlsafe_base64(32)
      record = create!(
        tenant: tenant, name: name, role: role,
        expires_at: expires_at, token_digest: digest(raw)
      )
      [ record, raw ]
    end

    def self.find_active(raw)
      return nil if raw.blank?

      active.find_by(token_digest: digest(raw))
    end

    def self.digest(raw)
      Digest::SHA256.hexdigest(raw)
    end

    def mark_used!
      update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def revoke!
      update!(revoked_at: Time.current) unless revoked?
    end

    def revoked?
      revoked_at.present?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def active?
      !revoked? && !expired?
    end
  end
end
