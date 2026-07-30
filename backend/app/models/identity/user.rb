# frozen_string_literal: true

module Identity
  # A global user identity. Lives in the shared public schema (Apartment-excluded)
  # because one user can belong to many tenants (ADR-0006). Tenant access is
  # granted via Membership (commit 2.2), not by which schema the row is in.
  class User < ApplicationRecord
    self.table_name = "users"

    # Adds: password/password_confirmation virtual attributes, bcrypt hashing into
    # password_digest, an #authenticate method, presence validation on create, and
    # a max length (72 bytes, the bcrypt limit). Requires the `bcrypt` gem.
    has_secure_password

    # One user, many tenants (ADR-0006), via memberships.
    has_many :memberships, class_name: "Identity::Membership", dependent: :destroy
    has_many :tenants, through: :memberships, source: :tenant

    # Refresh tokens for this user (ADR-0005). `dependent: :destroy` so removing a
    # user cleans up their tokens; "log out everywhere" revokes them in bulk.
    has_many :refresh_tokens, class_name: "Identity::RefreshToken", dependent: :destroy

    enum :status, { active: 0, invited: 1, suspended: 2 }, default: :active

    before_validation :normalize_email

    validates :email,
              presence: true,
              format: { with: URI::MailTo::EMAIL_REGEXP },
              uniqueness: { case_sensitive: false }

    scope :kept, -> { where(deleted_at: nil) }

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def deleted?
      deleted_at.present?
    end

    def full_name
      [ first_name, last_name ].compact_blank.join(" ")
    end

    private

    # citext already makes comparisons case-insensitive, but we still store a
    # canonical (stripped, lowercased) form so what we display is tidy and
    # consistent.
    def normalize_email
      self.email = email.strip.downcase if email.is_a?(String)
    end
  end
end
