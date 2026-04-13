require "rails_helper"
require "digest"

RSpec.describe "Authentication", type: :request, auth: :real do
  let!(:user) { User.create!(email: "me@example.com", password: "password") }

  def login_and_get_token
    post "/api/auth/session",
         params: { email: "me@example.com", password: "password" },
         as: :json
  
    expect(response).to have_http_status(:ok)
  
    JSON.parse(response.body)["token"]
  end

  describe "GET /api/books" do
    let(:email) { "auth-spec-#{SecureRandom.hex(4)}@example.com" }
    let(:password) { "password" }

    context "正常系" do
      it "returns 200 with valid Bearer token" do
        token = login_and_get_token
  
        get "/api/books",
            headers: { "Authorization" => "Bearer #{token}" }
  
        expect(response).to have_http_status(:ok)
      end
      
    end

    context "異常系" do
      it "returns 401 without Authorization header" do
        get "/api/books"
  
        expect(response).to have_http_status(:unauthorized)
        puts response.body
      end

      it "authorizationのtokenがクライアントからのrawの情報でない場合" do
        get "/api/books",
          headers: { "Authorization" => "Bearer aaaaaaooooo" },
          as: :json
        puts response.body

        expect(response).to have_http_status(:unauthorized)
      end

      it "Authorization header が Bearer のみのとき 401" do
        get "/api/books",
        headers: { "Authorization" => "Bearer " },
        as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "Authorization header が Bearer ではあるが、token が active 条件を満たさないとき 401" do

        user = User.create!(email: email, password: password)
  
        raw = SecureRandom.hex(32)
        digest = Digest::SHA256.hexdigest(raw)
  
        AccessToken.create!(
          user: user,
          token_digest: digest,
          expires_at: 1.second.ago
        )
  
        get "/api/books",
        headers: { "Authorization" => "Bearer #{raw}"},
        as: :json
  
        expect(response).to have_http_status(:unauthorized)

        puts response.body
  
      end
    end
  end
end