# frozen_string_literal: true

module Inventory
  class StockMovementSerializer < Blueprinter::Base
    field(:id) { |m| m.id.to_s }
    field(:product_id) { |m| m.product_id.to_s }
    field(:warehouse_id) { |m| m.warehouse_id.to_s }
    fields :movement_type, :quantity_delta, :created_at
  end
end
