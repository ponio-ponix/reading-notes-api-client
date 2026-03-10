RSpec.describe "Api::Auth::Session", type: :request, auth: :real do
  let!(:user) { User.create!(email: "me@example.com", password: "password", password_confirmation: "password") }

  describe "POST /api/auth/session" do
    it "returns token on success" do
      post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
    end

    it "returns 401 on invalid credentials" do
      post "/api/auth/session", params: { email: user.email, password: "wrong" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "auth + logout flow" do
    it "blocks without bearer and blocks after logout" do
      # no bearer -> 401
      get "/api/books"
      expect(response).to have_http_status(:unauthorized)

      # login -> token
      post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
      token = JSON.parse(response.body).fetch("token")

      # bearer -> 200
      get "/api/books", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      # logout -> 200
      delete "/api/auth/session", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      # same bearer -> 401
      get "/api/books", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end