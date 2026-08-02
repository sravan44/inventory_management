# frozen_string_literal: true

module Identity
  # Managing members of the CURRENT tenant is admin-only. Runs inside the
  # tenant-scoped stack, so it reads Current.membership (set by the gate).
  class MembershipPolicy < ApplicationPolicy
    def create?
      Current.membership&.admin?
    end

    def destroy?
      Current.membership&.admin?
    end
  end
end
