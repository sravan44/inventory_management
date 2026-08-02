require "rails_helper"

module Inventory
  RSpec.describe Warehouse, type: :model do
    it "is valid with name and code" do
      expect(build(:warehouse)).to be_valid
    end

    it "requires name and code" do
      expect(build(:warehouse, name: nil)).not_to be_valid
      expect(build(:warehouse, code: nil)).not_to be_valid
    end

    describe "code uniqueness" do
      it "rejects a duplicate code (case-insensitive) among live warehouses" do
        create(:warehouse, code: "WH-1")
        expect(build(:warehouse, code: "wh-1")).not_to be_valid
      end

      it "allows reusing a code after the original is soft-deleted" do
        create(:warehouse, code: "WH-1").soft_delete!
        expect(build(:warehouse, code: "WH-1")).to be_valid
      end
    end

    it "soft-deletes (deleted_at + active false, out of .kept)" do
      warehouse = create(:warehouse)
      warehouse.soft_delete!
      expect(warehouse.deleted?).to be(true)
      expect(warehouse.active).to be(false)
      expect(Warehouse.kept).not_to include(warehouse)
    end
  end
end
