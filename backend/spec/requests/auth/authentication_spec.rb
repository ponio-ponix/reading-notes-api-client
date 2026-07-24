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
      it "有効なBearer Tokenでは200を返す" do
        token = login_and_get_token
  
        get "/api/books",
            headers: { "Authorization" => "Bearer #{token}" }
  
        expect(response).to have_http_status(:ok)
      end
      
    end

    context "異常系" do
      it "Authorization headerがない場合は401を返す" do
        get "/api/books"
  
        expect(response).to have_http_status(:unauthorized)
      end

      it "保存済みdigestに一致しないBearer Tokenでは401を返す" do
        get "/api/books",
          headers: { "Authorization" => "Bearer aaaaaaooooo" },
          as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "BearerのみでTokenがない場合は401を返す" do
        get "/api/books",
          headers: { "Authorization" => "Bearer " },
          as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "期限切れのBearer Tokenでは401を返す" do

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
      end

      it "失効済みのBearer Tokenでは401を返す" do
        token = login_and_get_token
  
        get "/api/books",
            headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:ok)

        digest = Digest::SHA256.hexdigest(token)
        find_token = AccessToken.find_by(token_digest: digest)

        find_token.update!(revoked_at: Time.current)

        get "/api/books", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end