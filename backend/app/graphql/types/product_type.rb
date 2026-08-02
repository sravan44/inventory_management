# frozen_string_literal: true

module Types
  class ProductType < Types::BaseObject
    field :id, ID, null: false
    field :sku, String, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :unit_of_measure, String, null: true
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def id
      object.id.to_s
    end
  end
end
