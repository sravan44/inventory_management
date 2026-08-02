# frozen_string_literal: true

module Types
  # "Who am I in this tenant" — the GraphQL analogue of the REST /context endpoint.
  # Resolves from the request context set by GraphqlController.
  class ViewerType < Types::BaseObject
    field :email, String, null: true, description: "Current user's email."
    field :role, String, null: true, description: "The user's role in this tenant."
    field :tenant_subdomain, String, null: true, description: "The resolved tenant."

    def email
      object[:user]&.email
    end

    def role
      object[:membership]&.role
    end

    def tenant_subdomain
      object[:tenant]&.subdomain
    end
  end
end
