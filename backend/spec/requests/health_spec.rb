require "rails_helper"

# A REQUEST spec drives the app the way a real HTTP client would: it routes
# through middleware -> router -> controller and inspects the real response.
# That makes it the right level to prove an endpoint actually works
# end-to-end, as opposed to a unit test of the controller class in isolation.
RSpec.describe "Health", type: :request do
  describe "GET /up" do
    it "returns 200 OK" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end

    it "reports status ok as JSON" do
      get "/up"

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body).to have_key("time")
    end
  end
end
