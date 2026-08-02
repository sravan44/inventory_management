Rails.application.routes.draw do
  # Platform admin (Motor Admin, ADR-0015): mounted at /admin, HTTP-Basic-gated in
  # config/initializers/motor.rb. (RailsAdmin was attempted and deferred, ADR-0014.)
  mount Motor::Admin => "/admin"

  # GraphQL (ADR-0009): first-party SPA surface, served on a tenant subdomain.
  # User-JWT only (rejects API keys). See GraphqlController.
  post "/graphql", to: "graphql#execute"

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

      # Management (commit 3.2): tenants on the apex host; memberships tenant-scoped.
      resources :tenants, only: %i[create show update destroy]
      resources :memberships, only: %i[create destroy]

      # API keys (commit 3.3): tenant-scoped, admin-user managed.
      resources :api_keys, only: %i[index create destroy]

      # Inventory (Milestone 4). Individual CRUD is REST; listing + status changes
      # are GraphQL (ADR-0009), so no :index here.
      resources :products, only: %i[show create update destroy]
      resources :warehouses, only: %i[show create update destroy]

      # Stock: record a movement (write) + show one. Levels/ledger listing is GraphQL.
      resources :stock_movements, only: %i[create show]

      # Audit logs (ADR-0007), day-wise browsing for tenant admins.
      get "activity_logs/summary", to: "activity_logs#summary"
      get "activity_logs",         to: "activity_logs#index"
    end
  end
end

