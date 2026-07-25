require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings here take precedence over those in config/application.rb.

  config.enable_reloading = false

  # Eager load in CI to catch load-time errors; keep it fast locally.
  config.eager_load = ENV["CI"].present?

  config.public_file_server.enabled = true
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Render exceptions as normal responses (so our JSON error renders show).
  config.action_dispatch.show_exceptions = :rendered

  config.action_controller.action_on_unpermitted_parameters = :raise

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load

  # Don't shell out to pg_dump after migrating in CI (avoids a pg_dump
  # dependency/version-mismatch on the runner); the test schema is built by
  # running migrations directly.
  config.active_record.dump_schema_after_migration = false

  # Build the test DB by running migrations (see CI), NOT by loading a
  # structure.sql. This avoids needing psql on the runner and avoids stale-dump
  # problems with Apartment's per-tenant schemas. We migrate the test DB
  # explicitly, so disable the auto schema-maintenance that would try to load
  # structure.sql.
  config.active_record.maintain_test_schema = false

  # Allow arbitrary Host headers so subdomain request specs work (commit 1.4).
  config.hosts.clear

  # Mailer: capture deliveries in memory so specs can assert on them.
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "example.com" }
end
