# frozen_string_literal: true

# Rate limiting (commit 3.5). Throttles abusive traffic; tighter buckets on auth
# endpoints to blunt credential stuffing. rack-attack's railtie inserts the
# middleware automatically.
class Rack::Attack
  # In-memory counters are fine for dev/test and a single process. In production
  # (multi-process/instance) point this at Redis (Milestone 5) so limits are shared.
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Off by default in tests so normal request specs aren't throttled; the
  # rate-limit spec flips it on explicitly.
  Rack::Attack.enabled = !Rails.env.test?

  # General ceiling per IP (skip the docs UI so browsing Swagger isn't throttled).
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/api-docs")
  end

  # Tighter on login + refresh (credential stuffing / token abuse).
  throttle("auth/login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/login"
  end

  throttle("auth/refresh/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/refresh"
  end

  # Uniform JSON 429 with Retry-After.
  self.throttled_responder = lambda do |request|
    match = request.env["rack.attack.match_data"] || {}
    retry_after = (match[:period] || 60).to_s
    body = { error: { code: "rate_limited", message: "Too many requests. Slow down." } }
    [ 429, { "Content-Type" => "application/json", "Retry-After" => retry_after }, [ body.to_json ] ]
  end
end
