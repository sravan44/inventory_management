# Refresh tokens live in the public schema (global identity, ADR-0005). They back
# token rotation and "log out everywhere": each is a long-lived, revocable
# credential whose HASH we store — never the raw token.
class CreateRefreshTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true   # index supports "revoke all by user"
      t.string   :token_digest, null: false                # SHA-256 of the raw token
      t.datetime :expires_at,   null: false
      t.datetime :revoked_at                               # nil = still valid
      t.timestamps
    end

    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, :expires_at                 # for cleanup jobs
  end
end
