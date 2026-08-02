# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :viewer, Types::ViewerType, null: true,
                                      description: "The current user and their role in this tenant."

    # Listing lives in GraphQL (ADR-0009). Relay connection => cursor pagination
    # for free (first/after/last/before). Bounded by the schema's max_page_size.
    field :products, Types::ProductType.connection_type, null: false,
                                                         description: "Products in the current tenant." do
      argument :active, Boolean, required: false, description: "Filter by active flag."
      argument :query, String, required: false, description: "Search name/SKU."
    end

    field :warehouses, Types::WarehouseType.connection_type, null: false,
                                                             description: "Warehouses in the current tenant." do
      argument :active, Boolean, required: false, description: "Filter by active flag."
    end

    def viewer
      return nil unless context[:current_user]

      {
        user: context[:current_user],
        membership: context[:current_membership],
        tenant: context[:current_tenant]
      }
    end

    def products(active: nil, query: nil)
      scope = Inventory::Product.kept.order(created_at: :desc)
      scope = scope.where(active: active) unless active.nil?
      scope = scope.where("name ILIKE :q OR sku ILIKE :q", q: "%#{query}%") if query.present?
      scope
    end

    def warehouses(active: nil)
      scope = Inventory::Warehouse.kept.order(created_at: :desc)
      scope = scope.where(active: active) unless active.nil?
      scope
    end
  end
end
