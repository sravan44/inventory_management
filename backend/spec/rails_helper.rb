# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Prevent accidentally running the suite against production data.
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Keep the test schema in sync with migrations (loads structure.sql).
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures").to_s]

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
end
