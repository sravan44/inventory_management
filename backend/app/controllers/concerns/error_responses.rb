# frozen_string_literal: true

# The ONE JSON error shape for the whole API (API_DESIGN.md):
#
#   { "error": { "code": "...", "message": "...", "details": [...], "request_id": "..." } }
#
# `code` is a stable machine string clients switch on; `message` is human-readable;
# `details` is per-field validation info; `request_id` correlates to server logs.
# Common exceptions are mapped to it here so controllers don't repeat themselves.
module ErrorResponses
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "not_found", "Resource not found.")
    end

    rescue_from ActiveRecord::RecordInvalid do |error|
      render_error(:unprocessable_entity, "validation_failed",
                   "Validation failed.", details: errors_from(error.record))
    end

    rescue_from ActiveRecord::RecordNotUnique do
      render_error(:conflict, "conflict", "That record already exists.")
    end

    rescue_from ActionController::ParameterMissing do |error|
      render_error(:bad_request, "parameter_missing", error.message)
    end

    rescue_from ActionController::UnpermittedParameters do |error|
      render_error(:bad_request, "unpermitted_parameters", error.message)
    end

    rescue_from Pundit::NotAuthorizedError do
      render_error(:forbidden, "forbidden", "You are not allowed to perform this action.")
    end
  end

  private

  # Render the standard envelope. `details` is omitted when empty.
  def render_error(status, code, message, details: [])
    error = { code: code, message: message }
    error[:details] = details if details.present?
    error[:request_id] = request.request_id
    render json: { error: error }, status: status
  end

  def errors_from(record)
    record.errors.map { |e| { field: e.attribute, issue: e.message } }
  end
end
