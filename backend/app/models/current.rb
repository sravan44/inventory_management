# frozen_string_literal: true

# Request-scoped globals, reset automatically between requests by Rails' executor.
# Lets any layer read the request context without threading it through method
# signatures. Only the resolver/auth layers WRITE; everything else reads.
#
# An "actor" is whoever is making the request — a User (via JWT) or an ApiKey
# (third-party, ADR-0010). Policies read `Current.role` so they don't care which.
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :user, :membership, :api_key

  # The authenticated principal — a User or an ApiKey.
  def self.actor
    user || api_key
  end

  # The role for authorization: a user's membership role, or the key's role.
  def self.role
    membership&.role || api_key&.role
  end
end
