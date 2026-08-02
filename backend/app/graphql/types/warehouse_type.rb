# frozen_string_literal: true

module Types
  class WarehouseType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :code, String, null: false
    field :address, GraphQL::Types::JSON, null: true
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def id
      object.id.to_s
    end
  end
end
