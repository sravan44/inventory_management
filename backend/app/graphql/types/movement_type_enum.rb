# frozen_string_literal: true

module Types
  # GraphQL enum (uppercase) mapped to the model's movement_type values.
  class MovementTypeEnum < Types::BaseEnum
    value "RECEIPT", value: "receipt"
    value "ADJUSTMENT", value: "adjustment"
    value "TRANSFER_IN", value: "transfer_in"
    value "TRANSFER_OUT", value: "transfer_out"
    value "SALE", value: "sale"
  end
end
