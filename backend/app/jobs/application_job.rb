# frozen_string_literal: true

# Base class for background jobs (Identity::ProvisionTenantJob, etc.).
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that hit a deadlock.
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying record is no longer present.
  # discard_on ActiveJob::DeserializationError
end
