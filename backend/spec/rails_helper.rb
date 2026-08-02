# frozen_string_literal: true

require "spec_helper"
# FORCE the test environment. We use `=` not `||=` on purpose: the Docker `web`
# service sets RAILS_ENV=development, and a plain `||=` would leave it as
# development — so RSpec would run against the dev database. The test suite must
# always run in test, regardless of the container's RAILS_ENV.
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"

# Prevent accidentally running the suite against production data.
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# NOTE: we do NOT call `maintain_test_schema!` here. The test database is built by
# running migrations explicitly (locally and in CI) rather than loading a
# structure.sql — which keeps psql off the CI runner and avoids stale-dump issues
# with Apartment's per-tenant schemas. `config.active_record.maintain_test_schema`
# is set to false in config/environments/test.rb.

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures").to_s ]

  # Wrap each example in a transaction that rolls back at the end (fast, clean).
  # NOTE: specs that create/drop Postgres SCHEMAS via Apartment (tenant
  # provisioning / resolution) manage their own cleanup and may need
  # `use_transactional_fixtures` disabled per-example if DDL fights the outer
  # transaction — handled where relevant.
  config.use_transactional_fixtures = true

  # Infer spec type (:model, :request, ...) from the file's directory.
  config.infer_spec_type_from_file_location!

  # Trim Rails internals from failure backtraces.
  config.filter_rails_from_backtrace!

  # FactoryBot: expose build / build_stubbed / create without the FactoryBot
  # prefix. Prefer build_stubbed (no DB) > build (unsaved) > create (persisted).
  config.include FactoryBot::Syntax::Methods

  # Auto-prepare the test DB: run any pending migrations before the suite. We
  # build the test schema by migrating (not loading structure.sql), so this makes
  # `rspec` self-sufficient — no separate "migrate the test DB" step to forget.
  config.before(:suite) do
    ActiveRecord::Tasks::DatabaseTasks.migrate
  end
end
