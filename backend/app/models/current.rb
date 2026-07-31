# frozen_string_literal: true

# Request-scoped globals, reset automatically between requests by Rails' executor.
#
# Why this exists: it lets any layer read `Current.tenant` (and later
# `Current.user`, `Current.membership`) without threading those values through
# every method signature. That keeps call sites clean and avoids Law-of-Demeter
# violations like `request.env["..."].user.membership.role` sprinkled everywhere.
#
# CAUTION: because it's global-ish state, only the resolver/auth layers should
# WRITE to it; everything else reads. User + membership attributes arrive in
# Milestone 2.
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
  attribute :user
  attribute :membership
end
