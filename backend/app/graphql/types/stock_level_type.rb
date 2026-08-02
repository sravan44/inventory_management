# frozen_string_literal: true

module Types
  class StockLevelType < Types::BaseObject
    field :id, ID, null: false
    field :product, Types::ProductType, null: false
    field :warehouse, Types::WarehouseType, null: false
    field :quantity_on_hand, Integer, null: false
    field :quantity_reserved, Integer, null: false
    field :available_quantity, Integer, null: false

    def id
      object.id.to_s
    end
  end
end
