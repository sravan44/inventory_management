# frozen_string_literal: true

module Api
  module V1
    # Individual product CRUD (REST, ADR-0009). Listing + activate/deactivate are
    # GraphQL (commit 4.3). Tenant-scoped: inherits resolution + dual auth +
    # verify_authorized from TenantBaseController.
    class ProductsController < TenantBaseController
      def show
        product = Inventory::Product.kept.find(params[:id])
        authorize product
        render json: Inventory::ProductSerializer.render(product)
      end

      def create
        authorize Inventory::Product
        product = Inventory::Product.new(product_params)
        if product.save
          render json: Inventory::ProductSerializer.render(product), status: :created
        else
          render_product_errors(product)
        end
      end

      def update
        product = Inventory::Product.kept.find(params[:id])
        authorize product
        if product.update(product_params)
          render json: Inventory::ProductSerializer.render(product)
        else
          render_product_errors(product)
        end
      end

      def destroy
        product = Inventory::Product.kept.find(params[:id])
        authorize product
        product.soft_delete!
        head :no_content
      end

      private

      def product_params
        params.require(:product).permit(:sku, :name, :description, :unit_of_measure)
      end

      # A duplicate SKU is a conflict (409), distinct from other validation
      # failures (422) — matches API_DESIGN.md.
      def render_product_errors(product)
        if product.errors.of_kind?(:sku, :taken)
          render_error(:conflict, "sku_taken", "That SKU is already in use.")
        else
          render_error(:unprocessable_entity, "validation_failed",
                       "Validation failed.", details: errors_from(product))
        end
      end
    end
  end
end
