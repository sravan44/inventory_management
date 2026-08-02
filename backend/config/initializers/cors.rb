# frozen_string_literal: true

# CORS for the React SPA (ADR-0009, commit 3.5). Allow-list of known origins from
# ENV (comma-separated), NOT "*". Tokens travel in the Authorization header (not
# cookies), so credentials mode is off — that also sidesteps CSRF for the API.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(ENV.fetch("FRONTEND_ORIGINS", "http://localhost:5173").split(","))

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization],
             credentials: false
  end
end
