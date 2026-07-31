# frozen_string_literal: true

require "rails_helper"

# Central config for the OpenAPI doc that rswag generates from the request specs.
# `rake rswag:specs:swaggerize` runs the specs in doc mode and writes
# swagger/v1/swagger.yaml from what's declared here + each spec.
RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Inventory Management API",
        version: "v1",
        description: "Multi-tenant inventory management SaaS. Global auth endpoints " \
                     "are served on the apex host; tenant-scoped endpoints use a " \
                     "tenant subdomain."
      },
      paths: {},
      servers: [
        { url: "http://localhost:3000", description: "Local apex host (auth, /me)" },
        {
          url: "http://{subdomain}.lvh.me:3000",
          description: "Local tenant host (subdomain-scoped)",
          variables: { subdomain: { default: "acme" } }
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        }
      }
    }
  }

  # YAML is friendlier to diff in git than JSON.
  config.openapi_format = :yaml
end
