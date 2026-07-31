# frozen_string_literal: true

# Serves the generated OpenAPI file(s) from the `swagger/` directory at /api-docs.
Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.join("swagger").to_s

  # Inject the request host as the server URL at request time, so the docs work
  # on whatever host they're viewed from.
  # c.swagger_filter = lambda { |swagger, env| swagger }
end
