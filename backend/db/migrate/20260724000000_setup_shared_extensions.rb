# Runs FIRST (lowest version). Creates a dedicated `shared_extensions` schema and
# installs citext into it, so the extension's types are available to BOTH the
# public schema and every per-tenant schema (Apartment keeps shared_extensions in
# the search_path via `persistent_schemas`).
#
# Why not just install citext in `public`? When Apartment provisions a tenant it
# clones the public structure and rewrites the schema name (public -> tenant_x).
# That rewrite turns a `public.citext` type reference into `tenant_x.citext` — a
# type that doesn't exist — and provisioning fails with
# `type "tenant_x.citext" does not exist`. Extensions in a separate schema that
# Apartment never rewrites avoid this entirely.
class SetupSharedExtensions < ActiveRecord::Migration[7.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS shared_extensions;"
    execute "CREATE EXTENSION IF NOT EXISTS citext SCHEMA shared_extensions;"
  end

  def down
    execute "DROP EXTENSION IF EXISTS citext;"
    execute "DROP SCHEMA IF EXISTS shared_extensions;"
  end
end
