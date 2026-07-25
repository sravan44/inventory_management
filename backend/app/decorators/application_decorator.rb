# frozen_string_literal: true

# Base for presentation decorators. Wraps a model with SimpleDelegator so the
# decorator responds to everything the model does, plus its own computed/display
# methods. No gem, no view-layer coupling (works cleanly in an api_only app).
#
# Usage:
#   class Inventory::StockLevelDecorator < ApplicationDecorator
#     def available_quantity = quantity_on_hand - quantity_reserved
#   end
#   StockLevelDecorator.new(stock_level).available_quantity
#
# Decorators hold PRESENTATION logic only. Business rules go in services; JSON
# field selection goes in serializers (see docs/PATTERNS.md).
class ApplicationDecorator < SimpleDelegator
  def initialize(model)
    super
  end

  # The wrapped record, when you need it explicitly.
  def object
    __getobj__
  end

  def self.decorate_collection(records)
    records.map { |record| new(record) }
  end
end
