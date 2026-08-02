# frozen_string_literal: true

module Types
  # Domain-level errors returned INSIDE a mutation payload (GraphQL returns HTTP
  # 200; failures live here, not as HTTP status codes — ADR-0009). `code` mirrors
  # the REST error codes so clients can switch on the same strings.
  class UserErrorType < Types::BaseObject
    field :field, String, null: true
    field :code, String, null: false
    field :message, String, null: false
  end
end
