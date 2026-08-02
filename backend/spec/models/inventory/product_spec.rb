require "rails_helper"

module Inventory
  RSpec.describe Product, type: :model do
    it "is valid with sku and name" do
      expect(build(:product)).to be_valid
    end

    it "requires sku and name" do
      expect(build(:product, sku: nil)).not_to be_valid
      expect(build(:product, name: nil)).not_to be_valid
    end

    it "strips surrounding whitespace from the sku" do
      product = build(:product, sku: "  ABC-1  ")
      product.valid?
      expect(product.sku).to eq("ABC-1")
    end

    describe "sku uniqueness" do
      it "rejects a duplicate sku (case-insensitive) among live products" do
        create(:product, sku: "ABC-1")
        dup = build(:product, sku: "abc-1")
        expect(dup).not_to be_valid
        expect(dup.errors[:sku]).to include("has already been taken")
      end

      it "allows reusing a sku after the original is soft-deleted" do
        original = create(:product, sku: "ABC-1")
        original.soft_delete!
        expect(build(:product, sku: "ABC-1")).to be_valid
      end
    end

    describe "soft delete" do
      it "sets deleted_at, deactivates, and drops out of .kept" do
        product = create(:product)
        product.soft_delete!
        expect(product.deleted?).to be(true)
        expect(product.active).to be(false)
        expect(Product.kept).not_to include(product)
      end
    end
  end
end
