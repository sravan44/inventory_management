# Creates the `tenants` table in the SHARED public schema.
# Tenant is a global/identity record (ADR-0006): it must be visible regardless
# of which tenant schema is active, so it is an Apartment-excluded model and
# lives in `public`, not inside per-tenant schemas.
class CreateTenants < ActiveRecord::Migration[7.1]
  def change
    create_table :tenants do |t|
      t.string   :name,        null: false
      t.string   :subdomain,   null: false                 # normalized lowercase in the model
      t.string   :schema_name, null: false                 # the Postgres schema Apartment switches into
      t.integer  :status,      null: false, default: 0     # 0 = pending_provisioning (see enum)
      t.datetime :deleted_at                               # soft delete (nil = live)
      t.timestamps
    end

    # Enforce uniqueness at the DB level, not just in the model — a validation
    # alone can race under concurrency; the unique index is the real guarantee.
    add_index :tenants, :subdomain,   unique: true
    add_index :tenants, :schema_name, unique: true
  end
end
