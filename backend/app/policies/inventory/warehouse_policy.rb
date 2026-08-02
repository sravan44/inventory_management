# frozen_string_literal: true

module Inventory
  # Same role model as products: admin/staff manage, any authenticated actor reads.
  # Reads Current.role, so API keys are honored (ADR-0010).
  class WarehousePolicy < ApplicationPolicy
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
