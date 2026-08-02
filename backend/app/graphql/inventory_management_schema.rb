# frozen_string_literal: true

class InventoryManagementSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  # Batch-load associations to avoid N+1 in nested resolvers (ADR-0009).
  use GraphQL::Batch

  # DoS controls — GraphQL's answer to per-endpoint rate limits. A client can't
  # ask for arbitrarily deep/expensive queries.
  max_depth 12
  max_complexity 200
  default_max_page_size 100

  # Don't expose the schema via introspection in production. Dev/test keep it on
  # for tooling (GraphiQL, codegen).
  disable_introspection_entry_points if Rails.env.production?

  # Hide unhandled internal errors behind a generic message (details go to logs).
  rescue_from(StandardError) do |err, _obj, _args, _ctx, _field|
    Rails.logger.error("[GraphQL] #{err.class}: #{err.message}")
    raise GraphQL::ExecutionError, "Something went wrong." unless Rails.env.development?

    raise err
  end
end
