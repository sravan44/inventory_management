# frozen_string_literal: true

# Exception tracking (ADR-0016). Inert unless SENTRY_DSN is set, so dev/test/CI
# need no account. Point SENTRY_DSN at Sentry.io or a self-hosted, Sentry-compatible
# server (e.g. GlitchTip). Captures unhandled exceptions + background-job failures.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.breadcrumbs_logger = [ :active_support_logger ]
    config.traces_sample_rate = Float(ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.0"))
    config.send_default_pii = false # don't ship user PII to the tracker
  end
end
