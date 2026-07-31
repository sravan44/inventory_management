Rails.application.routes.draw do
  # API docs (ADR-0012): Swagger UI at /api-docs, OpenAPI file under the same path.
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # GET /up  ->  HealthController#show
  #
  # "up" is the conventional health-check path in modern Rails. The `as:`
  # gives us a named route helper (`health_check_path`) usable in tests/code.
  # We point it at our own controller (rather than Rails' built-in
  # rails/health) so the response shape is explicit and under our control.
  get "up" => "health#show", as: :health_check

  # Tenant-scoped sanity endpoint (commit 1.4). Served on a tenant subdomain;
  # resolves + switches schema via TenantScopedController.
  get "current_tenant" => "current_tenant#show"

  # Global (apex-host) API. Auth precedes any tenant context (commit 2.5).
  namespace :api do
    namespace :v1 do
      post "auth/register",   to: "auth#register"
      post "auth/login",      to: "auth#login"
      post "auth/refresh",    to: "auth#refresh"
      post "auth/logout",     to: "auth#logout"
      post "auth/logout_all", to: "auth#logout_all"
      get  "me",              to: "me#show"

      # Tenant-scoped (served on a tenant subdomain): full resolution + auth +
      # membership stack. First consumer of TenantBaseController (commit 2.6).
      get "context", to: "context#show"
    end
  end
end

