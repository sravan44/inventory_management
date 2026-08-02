# frozen_string_literal: true

module Inventory
  class StockLevelSerializer < Blueprinter::Base
    field(:id) { |l| l.id.to_s }
    field(:product_id) { |l| l.product_id.to_s }
    field(:warehouse_id) { |l| l.warehouse_id.to_s }
    fields :quantity_on_hand, :quantity_reserved
    field(:available_quantity) { |l| l.available_quantity }
  end
end
