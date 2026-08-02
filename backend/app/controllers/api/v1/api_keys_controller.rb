# frozen_string_literal: true

module Api
  module V1
    # API key management (tenant-scoped, admin users only). The raw key is returned
    # exactly ONCE, on create; never again.
    class ApiKeysController < TenantBaseController
      def index
        authorize Identity::ApiKey
        keys = Identity::ApiKey.where(tenant: Current.tenant).order(created_at: :desc)
        render json: keys.map { |key| api_key_json(key) }
      end

      def create
        authorize Identity::ApiKey
        record, raw = Identity::ApiKey.issue(
          tenant: Current.tenant,
          name: api_key_params[:name],
          role: api_key_params[:role].presence || :staff
        )
        audit("api_key.created", resource: record, metadata: { name: record.name, role: record.role })
        # `token` (the raw key) is included ONLY here.
        render json: api_key_json(record).merge(token: raw), status: :created
      end

      def destroy
        key = Identity::ApiKey.where(tenant: Current.tenant).find(params[:id])
        authorize key
        key.revoke!
        audit("api_key.revoked", resource: key, metadata: { name: key.name })
        head :no_content
      end

      private

      def api_key_params
        params.require(:api_key).permit(:name, :role)
      end

      def api_key_json(key)
        {
          id: key.id.to_s,
          name: key.name,
          role: key.role,
          last_used_at: key.last_used_at,
          expires_at: key.expires_at,
          revoked_at: key.revoked_at,
          created_at: key.created_at
        }
      end
    end
  end
end
