# frozen_string_literal: true

module Inventory
  # Append-only ledger row — the source of truth for stock. Immutable once written:
  # `readonly?` blocks updates/destroys after persistence, and a before_update guard
  # backs it up. Created only via StockMovementService (commit 4.6).
  class StockMovement < ApplicationRecord
    self.table_name = "stock_movements"

    belongs_to :product,   class_name: "Inventory::Product"
    belongs_to :warehouse, class_name: "Inventory::Warehouse"

    enum :movement_type, {
      receipt: 0, adjustment: 1, transfer_in: 2, transfer_out: 3, sale: 4
    }

    validates :movement_type, presence: true
    validates :quantity_delta, presence: true, numericality: { only_integer: true }

    before_update { raise ActiveRecord::ReadOnlyRecord, "stock_movements are append-only" }

    # Read-only once persisted → ActiveRecord refuses update/destroy. New records
    # (not yet persisted) stay writable so the initial insert succeeds.
    def readonly?
      persisted?
    end

    # The actor (a User or ApiKey in the public schema) — resolved on demand;
    # there's no cross-schema association, so we look it up by class + id.
    def actor
      return nil if actor_type.blank? || actor_id.blank?

      actor_type.constantize.find_by(id: actor_id)
    end
  end
end
