# frozen_string_literal: true

# Base class for controllers that operate WITHIN a tenant. Endpoints served on a
# tenant subdomain inherit from this and therefore get tenant resolution +
# schema switching for free. The apex/health endpoints inherit plain
# ApplicationController and are NOT tenant-scoped.
class TenantScopedController < ApplicationController
  include TenantResolution
end
