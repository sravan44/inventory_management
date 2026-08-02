# frozen_string_literal: true

module Api
  module V1
    # Manage members of the CURRENT tenant (tenant-scoped: resolution + auth +
    # membership + verify_authorized). Invite/revoke are REST; listing + role
    # changes are GraphQL (Milestone 4). Admin-only via Identity::MembershipPolicy.
    class MembershipsController < TenantBaseController
      # POST /api/v1/memberships — invite an email into this tenant.
      def create
        authorize Identity::Membership

        user = Identity::User.kept.find_or_create_by!(email: invite_email) do |u|
          # Invited-but-not-yet-registered: placeholder password; the invite flow
          # (later) lets them set a real one.
          u.password = SecureRandom.alphanumeric(24)
          u.status = :invited
        end

        membership = Identity::Membership.create!(
          user: user, tenant: Current.tenant, role: invite_params[:role], status: :invited
        )
        render json: membership_json(membership), status: :created
      end

      # DELETE /api/v1/memberships/:id — revoke access (soft).
      def destroy
        membership = Identity::Membership.where(tenant: Current.tenant).find(params[:id])
        authorize membership
        membership.revoke!
        head :no_content
      end

      private

      def invite_params
        params.require(:membership).permit(:email, :role)
      end

      def invite_email
        invite_params[:email].to_s.strip.downcase
      end

      def membership_json(membership)
        {
          id: membership.id.to_s,
          role: membership.role,
          status: membership.status,
          user: { id: membership.user.id.to_s, email: membership.user.email }
        }
      end
    end
  end
end
