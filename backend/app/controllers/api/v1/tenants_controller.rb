# frozen_string_literal: true

module Api
  module V1
    # Tenant management. Apex host (creating/selecting a tenant precedes tenant
    # context), authenticated. Authorization via Identity::TenantPolicy.
    class TenantsController < BaseController
      before_action :authenticate_user!

      # POST /api/v1/tenants — create + async provision (202). The creator becomes
      # the tenant's first admin.
      def create
        tenant = nil
        ActiveRecord::Base.transaction do
          tenant = Identity::Tenant.create!(tenant_params)
          Identity::Membership.create!(
            user: Current.user, tenant: tenant, role: :admin, status: :active
          )
        end
        Identity::ProvisionTenantJob.perform_later(tenant.id)
        render json: tenant_json(tenant), status: :accepted
      end

      # GET /api/v1/tenants/:id — members only. Non-members get 404 (not 403) so
      # we don't leak which tenant ids exist.
      def show
        tenant = Identity::Tenant.kept.find(params[:id])
        authorize tenant
        render json: tenant_json(tenant)
      rescue Pundit::NotAuthorizedError
        render_error(:not_found, "not_found", "Resource not found.")
      end

      # PATCH /api/v1/tenants/:id — admin only.
      def update
        tenant = Identity::Tenant.kept.find(params[:id])
        authorize tenant
        tenant.update!(tenant_update_params)
        render json: tenant_json(tenant)
      end

      # DELETE /api/v1/tenants/:id — admin only, soft delete.
      def destroy
        tenant = Identity::Tenant.kept.find(params[:id])
        authorize tenant
        tenant.soft_delete!
        head :no_content
      end

      private

      def tenant_params
        params.require(:tenant).permit(:name, :subdomain)
      end

      def tenant_update_params
        params.require(:tenant).permit(:name)
      end

      def tenant_json(tenant)
        { id: tenant.id.to_s, name: tenant.name, subdomain: tenant.subdomain, status: tenant.status }
      end
    end
  end
end
