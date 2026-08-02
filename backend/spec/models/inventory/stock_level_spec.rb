require "rails_helper"

module Inventory
  RSpec.describe StockLevel, type: :model do
    it "computes available quantity (on_hand - reserved)" do
      level = build(:stock_level, quantity_on_hand: 10, quantity_reserved: 3)
      expect(level.available_quantity).to eq(7)
    end

    it "is unique per (product, warehouse)" do
      existing = create(:stock_level)
      dup = build(:stock_level, product: existing.product, warehouse: existing.warehouse)
      expect(dup).not_to be_valid
    end

    it "rejects negative quantities" do
      expect(build(:stock_level, quantity_on_hand: -1)).not_to be_valid
      expect(build(:stock_level, quantity_reserved: -1)).not_to be_valid
    end

    it "uses optimistic locking (stale writes raise)" do
      level = create(:stock_level, quantity_on_hand: 5)
      a = StockLevel.find(level.id)
      b = StockLevel.find(level.id)

      a.update!(quantity_on_hand: 6)
      expect { b.update!(quantity_on_hand: 7) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
