# frozen_string_literal: true

module Inventory
  # A product / SKU within a tenant. Lives in the tenant schema, so uniqueness is
  # naturally per-tenant (a different tenant's schema is a different table).
  class Product < ApplicationRecord
    self.table_name = "products"

    before_validation :normalize_sku

    validates :name, presence: true
    validates :sku, presence: true

    # Case-insensitive uniqueness among LIVE products only — mirrors the partial
    # DB index, so a soft-deleted SKU can be reused. Skipped for deleted rows so
    # they don't collide with their own reissue.
    validates :sku,
              uniqueness: { case_sensitive: false, conditions: -> { where(deleted_at: nil) } },
              if: -> { deleted_at.nil? && sku.present? }

    scope :kept, -> { where(deleted_at: nil) }

    def soft_delete!
      update!(deleted_at: Time.current, active: false)
    end

    def deleted?
      deleted_at.present?
    end

    private

    def normalize_sku
      self.sku = sku.strip if sku.is_a?(String)
    end
  end
end
