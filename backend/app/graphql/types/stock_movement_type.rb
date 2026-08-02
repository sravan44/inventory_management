# frozen_string_literal: true

module Types
  class StockMovementType < Types::BaseObject
    field :id, ID, null: false
    field :product, Types::ProductType, null: false
    field :warehouse, Types::WarehouseType, null: false
    field :movement_type, Types::MovementTypeEnum, null: false
    field :quantity_delta, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def id
      object.id.to_s
    end
  end
end
