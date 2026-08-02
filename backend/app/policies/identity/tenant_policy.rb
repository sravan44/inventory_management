# frozen_string_literal: true

module Identity
  # Who can see/modify a Tenant. Membership is computed from the acting user +
  # the tenant record (these run on the apex host, so Current.membership isn't set).
  class TenantPolicy < ApplicationPolicy
    def show?
      membership.present?
    end

    def update?
      membership&.admin?
    end

    def destroy?
      update?
    end

    private

    def membership
      @membership ||= Identity::Membership.active.find_by(user: user, tenant: record)
    end
  end
end
