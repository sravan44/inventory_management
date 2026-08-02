require "rails_helper"

module Inventory
  RSpec.describe StockMovementService do
    let(:product)   { create(:product) }
    let(:warehouse) { create(:warehouse) }
    let(:actor)     { Identity::User.create!(email: "a@b.com", password: "secret123") }

    def record(type, delta)
      described_class.call(
        product: product, warehouse: warehouse,
        movement_type: type, quantity_delta: delta, actor: actor
      )
    end

    it "creates the level on first receipt and sets on_hand" do
      record(:receipt, 10)
      level = StockLevel.find_by(product: product, warehouse: warehouse)
      expect(level.quantity_on_hand).to eq(10)
    end

    it "applies signed deltas cumulatively" do
      record(:receipt, 10)
      record(:sale, -3)
      level = StockLevel.find_by(product: product, warehouse: warehouse)
      expect(level.quantity_on_hand).to eq(7)
    end

    it "writes a ledger row per movement" do
      record(:receipt, 10)
      record(:sale, -3)
      expect(StockMovement.where(product: product, warehouse: warehouse).count).to eq(2)
    end

    it "records the actor on the ledger" do
      movement = record(:receipt, 5)
      expect(movement.actor).to eq(actor)
    end

    describe "no-negative-stock rule" do
      it "raises InsufficientStock and rolls back (no ledger row, level unchanged)" do
        record(:receipt, 5)

        expect { record(:sale, -10) }.to raise_error(described_class::InsufficientStock)

        level = StockLevel.find_by(product: product, warehouse: warehouse)
        expect(level.quantity_on_hand).to eq(5)                 # unchanged
        expect(StockMovement.where(product: product).count).to eq(1) # only the receipt
      end
    end
  end
end
