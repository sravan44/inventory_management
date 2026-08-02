# Factories for the Inventory domain. Prefer build_stubbed / build over create
# where the DB isn't needed (ADR-0013).
FactoryBot.define do
  factory :product, class: "Inventory::Product" do
    sequence(:sku) { |n| "SKU-#{n}" }
    name { "Widget" }
    unit_of_measure { "each" }
    active { true }
  end

  factory :warehouse, class: "Inventory::Warehouse" do
    sequence(:code) { |n| "WH-#{n}" }
    name { "Main Warehouse" }
    address { { "city" => "Austin" } }
    active { true }
  end

  factory :stock_level, class: "Inventory::StockLevel" do
    association :product
    association :warehouse
    quantity_on_hand { 0 }
    quantity_reserved { 0 }
  end

  factory :stock_movement, class: "Inventory::StockMovement" do
    association :product
    association :warehouse
    movement_type { :receipt }
    quantity_delta { 10 }
  end
end
