require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings here take precedence over those in config/application.rb.

  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Assume TLS is terminated in front of the app; enable if not.
  # config.force_ssl = true
  config.assume_ssl = true

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout)) if ENV["RAILS_LOG_TO_STDOUT"].present?

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  config.i18n.fallbacks = true

  # Host allow-listing IS a security control in production. Configure the real
  # apex + wildcard tenant domain here, e.g.:
  # config.hosts << ".yourdomain.com"

  # Mailer (ADR-0011): real SMTP from ENV; deliveries always enqueued via jobs.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587),
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
end
