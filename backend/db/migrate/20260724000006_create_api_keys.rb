# Third-party API keys (ADR-0010). Public schema, tenant-scoped. We store only the
# SHA-256 digest of the key; the raw value is shown once at creation.
class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string   :name,         null: false
      t.string   :token_digest, null: false
      t.integer  :role,         null: false, default: 1   # enum, 1 = staff
      t.datetime :last_used_at
      t.datetime :expires_at                              # nil = no expiry
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :api_keys, :token_digest, unique: true
  end
end
