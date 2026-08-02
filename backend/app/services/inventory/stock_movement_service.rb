# frozen_string_literal: true

module Inventory
  # The ONLY way stock changes. In a single transaction it: locks the stock_level
  # row (SELECT … FOR UPDATE), enforces the no-negative-stock rule, appends the
  # ledger row (stock_movements), and updates the projection (stock_levels).
  #
  # Called by BOTH the REST endpoint and the GraphQL mutation — one behavior,
  # two transports (ADR-0009).
  class StockMovementService
    class InsufficientStock < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(product:, warehouse:, movement_type:, quantity_delta:, actor:, reference: nil)
      @product = product
      @warehouse = warehouse
      @movement_type = movement_type
      @quantity_delta = quantity_delta.to_i
      @actor = actor
      @reference = reference
    end

    def call
      ActiveRecord::Base.transaction do
        level = locked_level
        new_on_hand = level.quantity_on_hand + @quantity_delta

        if new_on_hand.negative?
          raise InsufficientStock, "Not enough stock: on hand #{level.quantity_on_hand}, delta #{@quantity_delta}."
        end

        movement = write_ledger!
        level.update!(quantity_on_hand: new_on_hand)
        movement
      end
    end

    private

    # Ensure the row exists (create_or_find_by! survives the create race), then
    # re-read it with a row lock so concurrent movements serialize on this row.
    def locked_level
      StockLevel.create_or_find_by!(product: @product, warehouse: @warehouse)
      StockLevel.lock.find_by!(product: @product, warehouse: @warehouse)
    end

    def write_ledger!
      StockMovement.create!(
        product: @product,
        warehouse: @warehouse,
        movement_type: @movement_type,
        quantity_delta: @quantity_delta,
        reference_type: @reference&.class&.name,
        reference_id: @reference&.id,
        actor_type: @actor&.class&.name,
        actor_id: @actor&.id
      )
    end
  end
end
