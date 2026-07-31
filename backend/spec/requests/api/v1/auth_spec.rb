require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    it "creates a user and returns a token pair" do
      post "/api/v1/auth/register",
           params: { user: { email: "sam@acme.io", password: "hunter2pw", first_name: "Sam" } }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["access_token"]).to be_present
      expect(body["refresh_token"]).to be_present
      expect(body["user"]["email"]).to eq("sam@acme.io")
    end

    it "returns 422 with details on invalid data" do
      post "/api/v1/auth/register", params: { user: { email: "bad", password: "x" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
    end

    it "returns 400 when the user param is missing" do
      post "/api/v1/auth/register", params: { email: "sam@acme.io" }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /api/v1/auth/login" do
    before { Identity::User.create!(email: "sam@acme.io", password: "hunter2pw") }

    it "returns tokens for valid credentials" do
      post "/api/v1/auth/login", params: { email: "sam@acme.io", password: "hunter2pw" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["refresh_token"]).to be_present
    end

    it "returns 401 for bad credentials" do
      post "/api/v1/auth/login", params: { email: "sam@acme.io", password: "nope" }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_credentials")
    end
  end

  describe "POST /api/v1/auth/refresh" do
    it "rotates and returns a new pair" do
      Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
      post "/api/v1/auth/login", params: { email: "sam@acme.io", password: "hunter2pw" }
      refresh = JSON.parse(response.body)["refresh_token"]

      post "/api/v1/auth/refresh", params: { refresh_token: refresh }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["access_token"]).to be_present
    end

    it "returns 401 for an invalid refresh token" do
      post "/api/v1/auth/refresh", params: { refresh_token: "nope" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/auth/logout" do
    it "revokes the refresh token and returns 204" do
      Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
      post "/api/v1/auth/login", params: { email: "sam@acme.io", password: "hunter2pw" }
      refresh = JSON.parse(response.body)["refresh_token"]

      post "/api/v1/auth/logout", params: { refresh_token: refresh }
      expect(response).to have_http_status(:no_content)

      # token no longer usable
      post "/api/v1/auth/refresh", params: { refresh_token: refresh }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/me" do
    it "returns the current user with a valid token" do
      user = Identity::User.create!(email: "sam@acme.io", password: "hunter2pw")
      token = Identity::JwtCodec.encode({ sub: user.id.to_s })

      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["user"]["email"]).to eq("sam@acme.io")
    end

    it "returns 401 without a token" do
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a garbage token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer not.a.jwt" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
