# frozen_string_literal: true

module Inventory
  # Shapes a Product for JSON responses (Blueprinter, ADR-0011 — first serializer).
  # The serializer owns the OUTPUT contract; the model owns persistence.
  class ProductSerializer < Blueprinter::Base
    field(:id) { |product| product.id.to_s } # bigint -> string (JS precision)
    fields :sku, :name, :description, :unit_of_measure, :active, :created_at
  end
end
