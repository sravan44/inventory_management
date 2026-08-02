# frozen_string_literal: true

module Inventory
  class StockMovementPolicy < ApplicationPolicy
    MANAGER_ROLES = %w[admin staff].freeze

    def create?
      MANAGER_ROLES.include?(Current.role)
    end

    def show?
      Current.role.present?
    end
  end
end
