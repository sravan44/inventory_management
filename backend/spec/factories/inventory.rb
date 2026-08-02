# Factories for the Inventory domain. Prefer build_stubbed / build over create
# where the DB isn't needed (ADR-0013).
FactoryBot.define do
  factory :product, class: "Inventory::Product" do
    sequence(:sku) { |n| "SKU-#{n}" }
    name { "Widget" }
    unit_of_measure { "each" }
    active { true }
  end
end
