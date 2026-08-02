# frozen_string_literal: true

module Inventory
  # A stock location within a tenant. Same shape/behavior as Product: tenant-scoped,
  # case-insensitive unique code among live rows, soft delete.
  class Warehouse < ApplicationRecord
    self.table_name = "warehouses"

    before_validation :normalize_code

    validates :name, presence: true
    validates :code, presence: true
    validates :code,
              uniqueness: { case_sensitive: false, conditions: -> { where(deleted_at: nil) } },
              if: -> { deleted_at.nil? && code.present? }

    scope :kept, -> { where(deleted_at: nil) }

    def soft_delete!
      update!(deleted_at: Time.current, active: false)
    end

    def deleted?
      deleted_at.present?
    end

    private

    def normalize_code
      self.code = code.strip if code.is_a?(String)
    end
  end
end
