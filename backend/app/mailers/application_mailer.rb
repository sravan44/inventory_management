# frozen_string_literal: true

# Base mailer. Concrete mailers (e.g. Identity::MembershipMailer for invitations)
# inherit this. Always send with `.deliver_later` so email goes through the
# worker queue and never blocks a request (docs/PATTERNS.md, ADR-0011).
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "no-reply@example.com")
  layout "mailer"
end
