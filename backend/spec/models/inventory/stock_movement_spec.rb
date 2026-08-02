require "rails_helper"

module Inventory
  RSpec.describe StockMovement, type: :model do
    it "is valid as a receipt with a signed delta" do
      expect(build(:stock_movement, movement_type: :receipt, quantity_delta: 10)).to be_valid
    end

    it "exposes movement types as an enum" do
      expect(StockMovement.movement_types.keys).to include("receipt", "sale", "transfer_in")
    end

    it "is append-only: cannot be updated once persisted" do
      movement = create(:stock_movement)
      expect { movement.update!(quantity_delta: 99) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "cannot be destroyed once persisted" do
      movement = create(:stock_movement)
      expect { movement.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "records a created_at but has no updated_at column" do
      movement = create(:stock_movement)
      expect(movement.created_at).to be_present
      expect(StockMovement.column_names).not_to include("updated_at")
    end

    it "resolves a polymorphic actor (e.g. a User)" do
      user = Identity::User.create!(email: "a@b.com", password: "secret123")
      movement = create(:stock_movement, actor_type: "Identity::User", actor_id: user.id)
      expect(movement.actor).to eq(user)
    end
  end
end
