# frozen_string_literal: true

# CORS for the React SPA + Swagger "Try it out" (ADR-0009, commit 3.5). Allow-list
# of origins, NOT "*". Tokens ride in the Authorization header (not cookies), so
# credentials mode is off — which also sidesteps CSRF for the API.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if ENV["FRONTEND_ORIGINS"].present?
      # Production/staging: explicit, comma-separated origins.
      origins(ENV["FRONTEND_ORIGINS"].split(","))
    else
      # Dev defaults: the Vite SPA, localhost, and any *.lvh.me:3000 subdomain
      # (so Swagger UI can call tenant endpoints across origins while testing).
      origins(
        "http://localhost:5173",
        "http://localhost:3000",
        %r{\Ahttp://[a-z0-9-]+\.lvh\.me:3000\z}
      )
    end

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization],
             credentials: false
  end
end
