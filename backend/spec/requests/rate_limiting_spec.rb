require "rails_helper"

# Rack::Attack is disabled in test by default (so it doesn't throttle other
# specs); this spec enables it and clears the counters around each example.
RSpec.describe "Rate limiting", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = false
  end

  it "throttles repeated logins from one IP with 429 + Retry-After" do
    11.times do
      post "/api/v1/auth/login", params: { email: "x@y.io", password: "nope" }
    end

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to be_present
    expect(JSON.parse(response.body).dig("error", "code")).to eq("rate_limited")
  end
end
