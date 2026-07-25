# Join table linking a global User to a Tenant with a role. Lives in the public
# schema (all three of user/tenant/membership are global identity — ADR-0006).
# This is the record that makes "one user, many tenants" real and is the
# authorization boundary: no membership => no access to that tenant.
class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      # index: false on user — the composite unique index below already covers
      # user_id-prefixed lookups, so a separate one would be redundant.
      t.references :user,   null: false, foreign_key: true, index: false
      t.references :tenant, null: false, foreign_key: true   # keeps a tenant_id index

      t.integer :role,   null: false                 # enum (admin/staff/purchasing/sales)
      t.integer :status, null: false, default: 0     # enum, 0 = invited

      # Lifecycle timestamps — when the invite was sent / accepted / revoked.
      t.datetime :invited_at
      t.datetime :joined_at
      t.datetime :revoked_at

      t.timestamps
    end

    # One membership per (user, tenant) pair — DB-enforced, not just validated.
    add_index :memberships, %i[user_id tenant_id], unique: true
  end
end
