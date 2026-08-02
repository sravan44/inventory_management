# frozen_string_literal: true

module Api
  module V1
    # Individual warehouse CRUD (REST). Listing is GraphQL (ADR-0009).
    class WarehousesController < TenantBaseController
      def show
        warehouse = Inventory::Warehouse.kept.find(params[:id])
        authorize warehouse
        render json: Inventory::WarehouseSerializer.render(warehouse)
      end

      def create
        authorize Inventory::Warehouse
        warehouse = Inventory::Warehouse.new(warehouse_params)
        if warehouse.save
          audit("warehouse.created", resource: warehouse, metadata: { code: warehouse.code })
          render json: Inventory::WarehouseSerializer.render(warehouse), status: :created
        else
          render_warehouse_errors(warehouse)
        end
      end

      def update
        warehouse = Inventory::Warehouse.kept.find(params[:id])
        authorize warehouse
        if warehouse.update(warehouse_params)
          audit("warehouse.updated", resource: warehouse)
          render json: Inventory::WarehouseSerializer.render(warehouse)
        else
          render_warehouse_errors(warehouse)
        end
      end

      def destroy
        warehouse = Inventory::Warehouse.kept.find(params[:id])
        authorize warehouse
        warehouse.soft_delete!
        audit("warehouse.deleted", resource: warehouse)
        head :no_content
      end

      private

      def warehouse_params
        params.require(:warehouse).permit(:name, :code, address: {})
      end

      def render_warehouse_errors(warehouse)
        if warehouse.errors.of_kind?(:code, :taken)
          render_error(:conflict, "code_taken", "That warehouse code is already in use.")
        else
          render_error(:unprocessable_entity, "validation_failed",
                       "Validation failed.", details: errors_from(warehouse))
        end
      end
    end
  end
end
