require "rails_helper"

# Proves the ONE error shape (ErrorResponses) across different failure types:
# validation (422), auth (401), and parameter-missing (400). Every error carries
# code + message + request_id; validation errors add per-field details.
RSpec.describe "API error envelope", type: :request do
  it "shapes validation errors consistently (422 + details)" do
    post "/api/v1/auth/register", params: { user: { email: "bad", password: "x" } }

    expect(response).to have_http_status(:unprocessable_entity)
    error = JSON.parse(response.body)["error"]
    expect(error["code"]).to eq("validation_failed")
    expect(error["message"]).to be_present
    expect(error["details"]).to be_an(Array).and be_present
    expect(error["request_id"]).to be_present
  end

  it "shapes auth errors consistently (401 + WWW-Authenticate)" do
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
    error = JSON.parse(response.body)["error"]
    expect(error["code"]).to eq("unauthorized")
    expect(error["request_id"]).to be_present
    expect(response.headers["WWW-Authenticate"]).to include("Bearer")
  end

  it "shapes a missing required param as 400" do
    post "/api/v1/auth/register", params: {}

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("parameter_missing")
  end
end
