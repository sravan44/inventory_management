# frozen_string_literal: true

module Identity
  # Links a User to a Tenant with a role. This is THE authorization boundary:
  # the JWT says who you are (global), the subdomain says which tenant, and the
  # Membership says whether you may act there and in what role (ADR-0004/0006).
  class Membership < ApplicationRecord
    self.table_name = "memberships"

    belongs_to :user,   class_name: "Identity::User"
    belongs_to :tenant, class_name: "Identity::Tenant"

    # `enum` auto-generates query scopes (Membership.active, Membership.admin, …)
    # and predicate methods (membership.active?, membership.admin?), plus bang
    # setters (membership.active!). We add richer lifecycle methods below that
    # also stamp timestamps.
    enum :role,   { admin: 0, staff: 1, purchasing: 2, sales: 3 }
    enum :status, { invited: 0, active: 1, revoked: 2 }, default: :invited

    validates :role, presence: true
    # Belt-and-suspenders with the DB unique index: one membership per pair.
    validates :user_id,
              uniqueness: { scope: :tenant_id,
                            message: "already has a membership in this tenant" }

    before_create :stamp_invited_at

    # Accept an invitation.
    def activate!
      update!(status: :active, joined_at: Time.current)
    end

    # Remove access without deleting history.
    def revoke!
      update!(status: :revoked, revoked_at: Time.current)
    end

    private

    def stamp_invited_at
      self.invited_at ||= Time.current
    end
  end
end
