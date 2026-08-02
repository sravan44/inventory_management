# frozen_string_literal: true

module Identity
  # Managing API keys is admin-USER only. We check Current.membership (not
  # Current.role), so an API key can never mint or revoke other API keys —
  # membership is nil for a key actor, so these all return false for keys.
  class ApiKeyPolicy < ApplicationPolicy
    def index?
      Current.membership&.admin?
    end

    def create?
      Current.membership&.admin?
    end

    def destroy?
      Current.membership&.admin?
    end
  end
end
