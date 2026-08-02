# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    private

    # Authorize via the same Pundit policies the REST controllers use. The policy
    # is inferred from the record's class; ours read Current.role, so this honors
    # both user and api-key actors. Raises a top-level error on denial.
    def authorize!(record, query)
      policy = Pundit.policy!(Current.user, record)
      return if policy.public_send(query)

      raise GraphQL::ExecutionError, "You are not allowed to perform this action."
    end
  end
end
