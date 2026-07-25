require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings here take precedence over those in config/application.rb.

  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # No caching in dev by default.
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Print deprecation notices to the Rails logger; surface disallowed ones.
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  # Raise on pending migrations.
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  config.active_job.verbose_enqueue_logs = true

  # Allow any Host in dev so tenant subdomains (e.g. acme.lvh.me) work.
  config.hosts.clear

  # Raise on unpermitted params to catch mistakes early.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Mailer (ADR-0011): write emails to tmp/mails in dev; never raise on failures.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :file
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
end
