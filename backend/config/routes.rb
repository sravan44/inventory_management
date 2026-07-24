Rails.application.routes.draw do
  # GET /up  ->  HealthController#show
  #
  # "up" is the conventional health-check path in modern Rails. The `as:`
  # gives us a named route helper (`health_check_path`) usable in tests/code.
  # We point it at our own controller (rather than Rails' built-in
  # rails/health) so the response shape is explicit and under our control.
  get "up" => "health#show", as: :health_check

  # Future routes (Milestone 2+) will be namespaced under /api/v1 and /graphql.
  # Kept empty here on purpose — commit 0.1 ships exactly one endpoint.
end
