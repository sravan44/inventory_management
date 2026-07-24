# frozen_string_literal: true

module Identity
  # A customer organization. Global/shared record (lives in the public schema,
  # Apartment-excluded) because a user can belong to many tenants (ADR-0006) and
  # tenant resolution happens by subdomain before any tenant schema is active.
  class Tenant < ApplicationRecord
    # Because the class is namespaced (Identity::Tenant), Rails would infer the
    # table name `identity_tenants`. We keep it as plain `tenants` — the module
    # is a code boundary, not a table prefix.
    self.table_name = "tenants"

    # Subdomains that must never be handed to a tenant because they collide with
    # platform/infra hostnames. Checked at validation time (ADR-0004).
    RESERVED_SUBDOMAINS = %w[
      www api admin app mail ftp smtp assets static cdn
      status help support blog docs dashboard billing
    ].freeze

    # A single DNS label: lowercase alphanumerics and hyphens, no leading/
    # trailing hyphen. Max length enforced separately (63 = DNS label limit).
    SUBDOMAIN_FORMAT = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/

    enum :status,
         { pending_provisioning: 0, active: 1, suspended: 2 },
         default: :pending_provisioning

    # Normalize BEFORE validation so uniqueness/format check the canonical value.
    before_validation :normalize_subdomain
    before_validation :assign_schema_name, on: :create

    validates :name, presence: true
    validates :subdomain,
              presence: true,
              length: { maximum: 63 },
              format: { with: SUBDOMAIN_FORMAT,
                        message: "must be lowercase letters, numbers, and hyphens" },
              uniqueness: true,
              exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
    validates :schema_name, presence: true, uniqueness: true

    # Prefer explicit scopes over a default_scope (which is a well-known footgun:
    # it silently leaks into every query and association).
    scope :kept, -> { where(deleted_at: nil) }

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def deleted?
      deleted_at.present?
    end

    private

    def normalize_subdomain
      self.subdomain = subdomain.strip.downcase if subdomain.is_a?(String)
    end

    # Derive the Postgres schema name from the subdomain. The `tenant_` prefix
    # keeps tenant schemas visually distinct from `public` and any reserved
    # Postgres schema names, and avoids a schema literally named e.g. `admin`.
    def assign_schema_name
      self.schema_name = "tenant_#{subdomain}" if schema_name.blank? && subdomain.present?
    end
  end
end
