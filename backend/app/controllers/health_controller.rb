# Liveness/readiness probe.
#
# Deliberately the SIMPLEST possible endpoint: no auth, no tenant resolution,
# no database call. Load balancers, Kubernetes, and uptime monitors hit this
# to ask "is the process up and serving HTTP?" It must stay cheap and never
# depend on anything that could be slow or down — otherwise a hiccup in the DB
# would make the app look dead and get killed/restarted needlessly.
#
# Inherits from ApplicationController, which for an --api app inherits from
# ActionController::API (a slimmer base than ActionController::Base — no
# cookies, no view rendering, no CSRF middleware, because a JSON API needs none
# of that).
class HealthController < ApplicationController
  def show
    render json: { status: "ok", time: Time.current.iso8601 }, status: :ok
  end
end
