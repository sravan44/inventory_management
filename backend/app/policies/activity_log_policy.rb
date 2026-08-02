# frozen_string_literal: true

# Reading a tenant's audit logs is admin-only. Headless (no AR record): authorized
# via `authorize :activity_log, :index?`. Uses Current.membership (a user admin) —
# API keys can't read the audit trail.
class ActivityLogPolicy < ApplicationPolicy
  def index?
    Current.membership&.admin?
  end

  def summary?
    index?
  end
end
