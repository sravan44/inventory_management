# frozen_string_literal: true

module Mutations
  # Record a stock movement (first-party). Same StockMovementService as REST.
  # Insufficient stock is a domain outcome → userErrors (HTTP 200); missing
  # product/warehouse → userErrors; role denial → top-level error via authorize!.
  class RecordStockMovement < BaseMutation
    argument :product_id, ID, required: true
    argument :warehouse_id, ID, required: true
    argument :movement_type, Types::MovementTypeEnum, required: true
    argument :quantity_delta, Integer, required: true

    field :movement, Types::StockMovementType, null: true
    field :user_errors, [ Types::UserErrorType ], null: false

    def resolve(product_id:, warehouse_id:, movement_type:, quantity_delta:)
      product = Inventory::Product.kept.find_by(id: product_id)
      warehouse = Inventory::Warehouse.kept.find_by(id: warehouse_id)

      if product.nil? || warehouse.nil?
        return { movement: nil, user_errors: [ { code: "not_found", message: "Product or warehouse not found." } ] }
      end

      authorize!(Inventory::StockMovement, :create?)

      movement = Inventory::StockMovementService.call(
        product: product, warehouse: warehouse,
        movement_type: movement_type, quantity_delta: quantity_delta,
        actor: Current.actor
      )
      Audit::Logger.log(action: "stock.recorded", resource: movement,
                        metadata: { movement_type: movement.movement_type, quantity_delta: movement.quantity_delta })
      { movement: movement, user_errors: [] }
    rescue Inventory::StockMovementService::InsufficientStock => e
      { movement: nil, user_errors: [ { code: "insufficient_stock", message: e.message } ] }
    end
  end
end
