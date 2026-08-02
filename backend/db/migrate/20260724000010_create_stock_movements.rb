# stock_movements: the append-only LEDGER — the source of truth for inventory.
# Insert-only (created_at, NO updated_at). Every change to stock is a signed
# quantity_delta row; stock_levels is derived from these and can be rebuilt by
# replaying the ledger.
class CreateStockMovements < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_movements do |t|
      t.references :product,   null: false, foreign_key: true, index: false
      t.references :warehouse, null: false, foreign_key: true, index: false

      t.integer :movement_type, null: false             # enum: receipt/adjustment/transfer_*/sale
      t.integer :quantity_delta, null: false            # signed (+in / -out)

      # Polymorphic link to the source doc (a PO/SO line later) — unused for now.
      t.string :reference_type
      t.bigint :reference_id

      # Polymorphic actor (a User or an ApiKey, both in the public schema). No
      # cross-schema FK — existence is validated at the app layer (ADR-0010, 3A).
      t.string :actor_type
      t.bigint :actor_id

      # Insert-only: created_at only, no updated_at.
      t.datetime :created_at, null: false
    end

    add_index :stock_movements, %i[product_id warehouse_id created_at]
    add_index :stock_movements, %i[reference_type reference_id]
    add_index :stock_movements, %i[actor_type actor_id]
    add_index :stock_movements, :movement_type
  end
end
