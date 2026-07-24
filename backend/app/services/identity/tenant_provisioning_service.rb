# frozen_string_literal: true

module Identity
  # Orchestrates turning a freshly-created Tenant (status: pending_provisioning)
  # into a usable one: create its Postgres schema and mark it active.
  #
  # Single Responsibility: this object owns the *provisioning workflow*. It does
  # NOT do raw SQL itself — it delegates schema creation to Apartment (our
  # tenancy boundary, per ADR-0002). If we ever swap Apartment for custom
  # middleware, only this file and the resolver change.
  class TenantProvisioningService
    def self.call(tenant)
      new(tenant).call
    end

    def initialize(tenant)
      @tenant = tenant
    end

    # Idempotent by design: safe to run again if a retry re-invokes it.
    def call
      create_schema
      activate!
      @tenant
    end

    private

    attr_reader :tenant

    def create_schema
      # Apartment::Tenant.create builds the schema and loads the current DB
      # structure into it (excluded-model tables like `tenants` stay in public).
      Apartment::Tenant.create(tenant.schema_name)
    rescue Apartment::TenantExists
      # A previous run (or a job retry) already made the schema. Not an error —
      # continue so we still reach activate!. This is what makes the service
      # safe to re-run.
      Rails.logger.info(
        "[TenantProvisioning] schema #{tenant.schema_name} already exists; skipping create"
      )
    end

    def activate!
      tenant.update!(status: :active)
    end
  end
end
