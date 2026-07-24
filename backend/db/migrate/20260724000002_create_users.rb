# Creates the `users` table in the SHARED public schema.
# User is a global identity (ADR-0006): one account can belong to many tenants,
# so it must live in `public` and be Apartment-excluded, not duplicated per tenant.
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    # citext = case-insensitive text. Storing email as citext makes uniqueness
    # and lookups case-insensitive AT THE DATABASE LEVEL, so "A@B.com" and
    # "a@b.com" are the same value without any LOWER() gymnastics in queries.
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users do |t|
      t.citext   :email,           null: false
      t.string   :password_digest, null: false          # bcrypt hash (never the raw password)
      t.string   :first_name
      t.string   :last_name
      t.integer  :status,          null: false, default: 0   # 0 = active (see enum)
      t.datetime :deleted_at                                 # soft delete
      t.timestamps
    end

    # Unique at the DB level (the real guarantee). Because the column is citext,
    # this index is inherently case-insensitive.
    add_index :users, :email, unique: true
  end
end
