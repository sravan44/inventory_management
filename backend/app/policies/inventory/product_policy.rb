# frozen_string_literal: true

module Inventory
  # First policy that HONORS API keys: it reads Current.role (a user's membership
  # role OR an api_key's role), so a third-party key with the right role can manage
  # inventory. (Identity policies use Current.membership, blocking keys.)
  class ProductPolicy < ApplicationPolicy
    MANAGER_ROLES = %w[admin staff].freeze

    def show?
      Current.role.present?
    end

    def create?
      MANAGER_ROLES.include?(Current.role)
    end

    def update?
      create?
    end

    def destroy?
      create?
    end
  end
end
