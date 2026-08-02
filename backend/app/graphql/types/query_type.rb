# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    # Listing/read fields (products, warehouses, stock, …) are added in Milestone 4.
    field :viewer, Types::ViewerType, null: true,
                                      description: "The current user and their role in this tenant."

    def viewer
      return nil unless context[:current_user]

      {
        user: context[:current_user],
        membership: context[:current_membership],
        tenant: context[:current_tenant]
      }
    end
  end
end
