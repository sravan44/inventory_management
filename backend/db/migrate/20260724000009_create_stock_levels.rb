# stock_levels: the materialized PROJECTION of current stock (a read cache of the
# stock_movements ledger). One row per (product, warehouse). Written ONLY by
# StockMovementService (commit 4.6) — never edited directly. CHECK constraints and
# optimistic locking are the last-line guards against negative or racing writes.
class CreateStockLevels < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_levels do |t|
      t.references :product,   null: false, foreign_key: true, index: false
      t.references :warehouse, null: false, foreign_key: true
      t.integer :quantity_on_hand,  null: false, default: 0
      t.integer :quantity_reserved, null: false, default: 0
      t.integer :lock_version,      null: false, default: 0   # optimistic locking (Rails)
      t.timestamps
    end

    add_index :stock_levels, %i[product_id warehouse_id], unique: true

    add_check_constraint :stock_levels, "quantity_on_hand >= 0",  name: "stock_levels_on_hand_non_negative"
    add_check_constraint :stock_levels, "quantity_reserved >= 0", name: "stock_levels_reserved_non_negative"
  end
end
