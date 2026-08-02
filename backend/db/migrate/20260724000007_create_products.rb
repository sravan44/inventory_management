# Products live in the TENANT schema (not excluded from Apartment), so each tenant
# gets its own products table. The unique index is PARTIAL — only across live
# (non-deleted) rows — so a SKU can be reused after its product is soft-deleted
# (standard inventory practice). `lower(sku)` makes it case-insensitive.
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string   :sku,             null: false
      t.string   :name,            null: false
      t.text     :description
      t.string   :unit_of_measure
      t.boolean  :active,          null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :products, "lower(sku)",
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_products_on_lower_sku_where_kept"
  end
end
