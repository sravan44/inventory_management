# frozen_string_literal: true

module Api
  module V1
    # Base for TENANT-SCOPED API endpoints. Pipeline:
    #   1. within_tenant     — subdomain -> Current.tenant + switch schema (around)
    #   2. authenticate_actor! — Bearer JWT (user+membership) OR Api-Key (ADR-0010)
    #   3. verify_authorized — fail closed: every action MUST call `authorize`
    #
    # The apex auth endpoints inherit BaseController directly and skip this stack.
    class TenantBaseController < BaseController
      include TenantResolution
      include ActorAuthentication
      include Auditable

      before_action :authenticate_actor!

      after_action :verify_authorized
    end
  end
end
