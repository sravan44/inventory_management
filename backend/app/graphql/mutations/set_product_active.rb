# frozen_string_literal: true

module Mutations
  # Status-change mutation (ADR-0009: GraphQL owns status changes). Activate or
  # deactivate a product. Domain problems come back as userErrors (HTTP stays 200);
  # authorization denial is a top-level error (via authorize!).
  class SetProductActive < BaseMutation
    argument :id, ID, required: true
    argument :active, Boolean, required: true

    field :product, Types::ProductType, null: true
    field :user_errors, [ Types::UserErrorType ], null: false

    def resolve(id:, active:)
      product = Inventory::Product.kept.find_by(id: id)

      if product.nil?
        return { product: nil, user_errors: [ { code: "not_found", message: "Product not found." } ] }
      end

      authorize!(product, :update?)   # ProductPolicy#update? on Current.role
      product.update!(active: active)

      Audit::Logger.log(action: active ? "product.activated" : "product.deactivated", resource: product)
      { product: product, user_errors: [] }
    end
  end
end
