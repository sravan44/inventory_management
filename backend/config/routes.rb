Rails.application.routes.draw do
  # GET /up  ->  HealthController#show
  #
  # "up" is the conventional health-check path in modern Rails. The `as:`
  # gives us a named route helper (`health_check_path`) usable in tests/code.
  # We point it at our own controller (rather than Rails' built-in
  # rails/health) so the response shape is explicit and under our control.
  get "up" => "health#show", as: :health_check

  # Tenant-scoped sanity endpoint (commit 1.4). Served on a tenant subdomain;
  # resolves + switches schema via TenantScopedController. Real resource routes
  # arrive under /api/v1 and /graphql in later milestones.
  get "current_tenant" => "current_tenant#show"
end
