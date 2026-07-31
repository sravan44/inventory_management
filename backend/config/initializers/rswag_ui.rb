# frozen_string_literal: true

# Serves Swagger UI at /api-docs, pointed at our generated OpenAPI file.
Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "Inventory Management API V1"
end
