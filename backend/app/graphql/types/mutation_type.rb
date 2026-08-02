# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :set_product_active, mutation: Mutations::SetProductActive

    # Placeholder kept so the mutation surface is never empty as fields come/go.
    field :ping, String, null: false, description: "Mutation-surface health check."

    def ping
      "pong"
    end
  end
end
