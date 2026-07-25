require "rails_helper"

module Identity
  RSpec.describe Membership, type: :model do
    let(:user)   { User.create!(email: "a@b.com", password: "secret123") }
    let(:tenant) { Tenant.create!(name: "Acme", subdomain: "acme") }

    def build_membership(**attrs)
      Membership.new({ user: user, tenant: tenant, role: :admin }.merge(attrs))
    end

    it "is valid with user, tenant, and role" do
      expect(build_membership).to be_valid
    end

    it "requires a role" do
      expect(build_membership(role: nil)).not_to be_valid
    end

    it "defaults status to invited and stamps invited_at on create" do
      membership = build_membership
      membership.save!
      expect(membership.status).to eq("invited")
      expect(membership.invited_at).to be_present
    end

    describe "uniqueness" do
      it "forbids two memberships for the same user + tenant" do
        build_membership.save!
        dup = build_membership(role: :staff)
        expect(dup).not_to be_valid
        expect(dup.errors[:user_id]).to include("already has a membership in this tenant")
      end

      it "allows the same user in a different tenant" do
        build_membership.save!
        other = Tenant.create!(name: "Beta", subdomain: "beta")
        expect(build_membership(tenant: other)).to be_valid
      end
    end

    describe "#activate!" do
      it "sets status active and stamps joined_at" do
        membership = build_membership
        membership.save!
        membership.activate!
        expect(membership.reload).to be_active
        expect(membership.joined_at).to be_present
      end
    end

    describe "#revoke!" do
      it "sets status revoked and stamps revoked_at" do
        membership = build_membership
        membership.save!
        membership.revoke!
        expect(membership.reload).to be_revoked
        expect(membership.revoked_at).to be_present
      end
    end

    it "connects users and tenants as many-to-many" do
      build_membership.save!
      expect(user.reload.tenants).to include(tenant)
      expect(tenant.reload.users).to include(user)
    end
  end
end
