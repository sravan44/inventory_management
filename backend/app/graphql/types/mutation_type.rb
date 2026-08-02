# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Status-change mutations (setProductActive, recordStockMovement, …) arrive in
    # Milestone 4. `ping` is a placeholder so the mutation surface is non-empty.
    field :ping, String, null: false, description: "Mutation-surface health check."

    def ping
      "pong"
    end
  end
end
