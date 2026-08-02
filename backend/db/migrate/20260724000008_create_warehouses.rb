# Warehouses live in the TENANT schema. Partial, case-insensitive unique index on
# `code` (across live rows only) — a code can be reused after soft-delete, same
# pattern as products.
class CreateWarehouses < ActiveRecord::Migration[7.1]
  def change
    create_table :warehouses do |t|
      t.string   :name,       null: false
      t.string   :code,       null: false
      t.jsonb    :address,    null: false, default: {}
      t.boolean  :active,     null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :warehouses, "lower(code)",
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_warehouses_on_lower_code_where_kept"
  end
end
