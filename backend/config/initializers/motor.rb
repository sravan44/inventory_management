# frozen_string_literal: true

# Motor Admin (ADR-0015) — the platform admin UI. Mounted at /admin (see routes).
# It operates on the `public` schema (global identity models); tenant-scoped data
# + a tenant switcher are a later iteration.
#
# Access gate: HTTP Basic against ADMIN_USER / ADMIN_PASSWORD (fails closed if
# either is blank). This is the same stopgap approach as before; a super-admin
# session/SSO using users.super_admin is the follow-up. We reopen Motor's base
# controller inside `to_prepare` so it survives code reloading in development.
Rails.application.config.to_prepare do
  Motor::ApplicationController.class_eval do
    before_action :authenticate_platform_admin!

    private

    def authenticate_platform_admin!
      authenticate_or_request_with_http_basic("Platform Admin") do |username, password|
        expected_user = ENV["ADMIN_USER"].to_s
        expected_pass = ENV["ADMIN_PASSWORD"].to_s
        expected_user.present? && expected_pass.present? &&
          ActiveSupport::SecurityUtils.secure_compare(username, expected_user) &&
          ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
      end
    end
  end
end
