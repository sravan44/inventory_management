# frozen_string_literal: true

module Inventory
  # Materialized projection of current stock for a (product, warehouse). Written
  # only by StockMovementService (commit 4.6). `lock_version` gives Rails optimistic
  # locking automatically (concurrent writers get StaleObjectError).
  class StockLevel < ApplicationRecord
    self.table_name = "stock_levels"

    belongs_to :product,   class_name: "Inventory::Product"
    belongs_to :warehouse, class_name: "Inventory::Warehouse"

    validates :product_id, uniqueness: { scope: :warehouse_id }
    validates :quantity_on_hand,  numericality: { greater_than_or_equal_to: 0 }
    validates :quantity_reserved, numericality: { greater_than_or_equal_to: 0 }

    def available_quantity
      quantity_on_hand - quantity_reserved
    end
  end
end
