require_relative "boot"

# Require ONLY the frameworks we use — not `rails/all`. This deliberately omits
# Active Storage, Action Mailbox, Action Text, and Action Cable: we don't use
# them, and loading them would (a) require a config/storage.yml and (b) trip an
# eager-load path conflict in CI. Add one back the day we actually need it.
require "rails"

require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"   # transactional email (ADR-0011)
require "action_view/railtie"     # mailer templates
# require "active_storage/engine"
# require "action_mailbox/engine"
# require "action_text/engine"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems limited to :test,
# :development, or :production.
Bundler.require(*Rails.groups)

module InventoryManagement
  class Application < Rails::Application
    # Initialize configuration defaults for the Rails version in use.
    config.load_defaults 7.1

    # NOT api_only. We keep the FULL Rails middleware stack (sessions, cookies,
    # flash, view rendering) so server-rendered pieces work without gymnastics:
    # ActionMailer templates and a future admin UI (RailsAdmin/Avo) need it.
    #
    # We're still API-FIRST: our JSON controllers inherit ActionController::API
    # (the lean base — see ApplicationController), so they get none of that weight
    # and no CSRF token requirement. The heavier stack is simply available to the
    # few web/admin controllers that will need it later. Views are kept to a
    # minimum (mailer layouts only for now).
    config.api_only = false

    # Dump the schema as structure.sql (not schema.rb) so Postgres-specific
    # features survive: multiple schemas (Apartment), partial unique indexes,
    # citext, jsonb (ADR-0002, commit 1.1).
    config.active_record.schema_format = :sql

    # ActiveJob adapter: swapped to Sidekiq in Milestone 5. Default for now.
    # config.active_job.queue_adapter = :sidekiq

    # Autoload domain code under app/** as usual (Zeitwerk). Namespaced modules
    # like Identity::User live at app/models/identity/user.rb.

    # Keep generators lean — we're API-first, so don't scaffold helpers, assets,
    # or JS; use RSpec; no fixtures. This enforces "minimal ERB/views".
    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.helper false
      g.assets false
      g.javascripts false
    end
  end
end
