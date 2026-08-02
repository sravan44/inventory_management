# frozen_string_literal: true

module Inventory
  class WarehouseSerializer < Blueprinter::Base
    field(:id) { |warehouse| warehouse.id.to_s }
    fields :name, :code, :address, :active, :created_at
  end
end
