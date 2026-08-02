# frozen_string_literal: true

module Api
  module V1
    # Record a stock movement (REST). The third-party record path; the SPA uses the
    # GraphQL mutation. Both call the SAME StockMovementService.
    class StockMovementsController < TenantBaseController
      def create
        authorize Inventory::StockMovement
        product = Inventory::Product.kept.find(movement_params[:product_id])
        warehouse = Inventory::Warehouse.kept.find(movement_params[:warehouse_id])

        movement = Inventory::StockMovementService.call(
          product: product,
          warehouse: warehouse,
          movement_type: movement_params[:movement_type],
          quantity_delta: movement_params[:quantity_delta],
          actor: Current.actor
        )
        audit("stock.recorded", resource: movement, metadata: {
          movement_type: movement.movement_type, quantity_delta: movement.quantity_delta,
          product_id: product.id, warehouse_id: warehouse.id
        })
        render json: Inventory::StockMovementSerializer.render(movement), status: :created
      rescue Inventory::StockMovementService::InsufficientStock => e
        render_error(:conflict, "insufficient_stock", e.message)
      end

      def show
        movement = Inventory::StockMovement.find(params[:id])
        authorize movement
        render json: Inventory::StockMovementSerializer.render(movement)
      end

      private

      def movement_params
        params.require(:stock_movement)
              .permit(:product_id, :warehouse_id, :movement_type, :quantity_delta)
      end
    end
  end
end
