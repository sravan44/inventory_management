# Platform-level admin flag (distinct from a tenant "admin" role via Membership).
# A super_admin manages the whole platform (tenants, users) via RailsAdmin
# (ADR-0014). Defaults to false — nobody is a platform admin by accident.
class AddSuperAdminToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :super_admin, :boolean, null: false, default: false
  end
end
