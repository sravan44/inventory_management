# Never write these to logs (mass-assignment/secret hygiene, OWASP).
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn
  password password_confirmation api_key access_token refresh_token authorization
]
