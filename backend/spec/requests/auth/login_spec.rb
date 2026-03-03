require "rails_helper"

RSpec.describe "Auth::Login", type: :request do
  describe "POST /api/auth/login" do
    let!(:user) { User.create!(email: "me@example.com", password: "password") }

    it "returns token when credentials are valid" do
      post "/api/auth/login",
           params: { email: "me@example.com", password: "password" },
           as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
    end
  end
end