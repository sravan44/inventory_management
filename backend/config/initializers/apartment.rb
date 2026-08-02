# frozen_string_literal: true

# Apartment configuration — schema-per-tenant on PostgreSQL (ADR-0002).
# Gem: ros-apartment (the maintained fork of the original apartment gem),
# required as "apartment" so the module name stays `Apartment`.
#
# IMPORTANT: commit 1.1 wires the gem in a BOOT-SAFE way, before the Tenant
# model or tenants table exist. Nothing here may reference a model/table that
# isn't created yet, or the app won't boot. The stubs below get filled in as
# later commits add those pieces.

Apartment.configure do |config|
  # Use PostgreSQL SCHEMAS (namespaces inside one database) — the schema-per-
  # tenant model. If this were false, Apartment would create a separate database
  # per tenant instead. Schemas keep everything in one instance/one database.
  config.use_schemas = true

  # Schemas ALWAYS kept in the search_path — for the default connection AND every
  # tenant. We keep Postgres extensions (citext, ...) in `shared_extensions` so
  # their types resolve inside tenant schemas and, crucially, are NOT rewritten
  # when Apartment clones public -> tenant during provisioning. Without this,
  # provisioning fails with `type "tenant_x.citext" does not exist`.
  config.persistent_schemas = [ "shared_extensions" ]

  # We dump the schema as SQL (config.active_record.schema_format = :sql in
  # application.rb), not Ruby. Without this, ros-apartment ignores that and
  # always tries to `load` db/schema.rb to build new tenant schemas — a file
  # that never gets created under schema_format = :sql, so every tenant
  # creation raises Apartment::FileNotFound. `use_sql = true` switches to the
  # adapter that clones the `public` schema directly (via pg_dump), matching
  # our SQL schema format.
  config.use_sql = true

  # Models that live ONCE in the shared `public` schema instead of being copied
  # into every tenant schema. These are the global identity models (a user can
  # belong to many tenants — ADR-0006). Empty for now; each entry is added in
  # the commit that creates the model:
  #   Milestone 2 -> Identity::User, Identity::Tenant, Identity::Membership,
  #                  Identity::RefreshToken
  #   Milestone 3 -> Identity::ApiKey
  config.excluded_models = [
    "Identity::Tenant",       # added commit 1.2
    "Identity::User",         # added commit 2.1
    "Identity::Membership",   # added commit 2.2
    "Identity::RefreshToken", # added commit 2.3
    "Identity::ApiKey"        # added commit 3.3
  ]

  # The set of tenant schemas Apartment manages. `rake apartment:migrate` fans
  # migrations across every name in this list. Now sourced from the Tenant table.
  # Guarded with table_exists? so it stays boot-safe: during the very migration
  # that creates `tenants`, the table isn't there yet, so we return [] instead of
  # raising.
  config.tenant_names = lambda do
    if ActiveRecord::Base.connection.table_exists?("tenants")
      Identity::Tenant.pluck(:schema_name)
    else
      []
    end
  end

  # Tenant used when none is active (the shared/global context, e.g. the apex
  # host handling login before any tenant is chosen). NOTE: ros-apartment 3.4+
  # renamed this from `default_schema` to `default_tenant`.
  config.default_tenant = "public"
end

# The subdomain "elevator" auto-switches the active schema based on the request
# subdomain. It is deliberately NOT enabled here — that's commit 1.4
# (TenantResolver), which also returns 404 for unknown subdomains and blocks
# suspended tenants. Enabling it now would break every request (no tenants exist).
#
# Rails.application.config.middleware.use Apartment::Elevators::Subdomain
