require "rails_helper"

RSpec.describe "Api::Auth::Session", type: :request, auth: :real do
  let!(:user) { User.create!(email: "me@example.com", password: "password", password_confirmation: "password") }

  describe "POST /api/auth/session" do
    let(:email) { "auth-spec-#{SecureRandom.hex(4)}@example.com" }
    let(:password) { "password" }

    context "正常系" do
      it "returns token on success" do
        post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)

        expect(body["token"]).to be_present
      end

      it "ログインが成功しAccessTokenが一件増えるはず" do 
        expect {
          post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
        }.to change(AccessToken, :count).by(1)
      end


      it "ログイン成功時、raw tokenは返るがDBにはdigestしか保存されない" do
        post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
        expect(response).to have_http_status(:ok)
        # 

        body = JSON.parse(response.body)

        responseDigest = Digest::SHA256.hexdigest(body["token"])

        user1 = User.find_by(email: user.email)

        user_AccessToken = AccessToken.find_by(user: user1)

        expect(body["token"]).not_to eq(user_AccessToken.token_digest)
        expect(responseDigest).to eq(user_AccessToken.token_digest)

        #dbのカラムの確認をする
      end
            
    end

    context "異常系" do
      it "returns 401 on invalid credentials" do
        post "/api/auth/session", params: { email: user.email, password: "wrong" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/auth/session" do
    context "正常系" do
      it "logoutができる（有効なBearer Tokenでlogoutした場合、対応するAccessTokenのrevoked_atがnilから日時へ変わる" do
        
        post "/api/auth/session", params: { email: user.email, password: "password" }, as: :json
        token = JSON.parse(response.body).fetch("token")

        digest = Digest::SHA256.hexdigest(token)

        delete "/api/auth/session", headers: { "Authorization" => "Bearer #{token}" }

        accessModel = AccessToken.find_by(token_digest: digest)
        expect(accessModel.revoked_at).to be_a(ActiveSupport::TimeWithZone)

      end
    end

    context "異常系" do
      it "Bearer tokenなしのアクセスと、logout後の同じtokenでのアクセスを拒否する" do
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

      it "ログインが成功せずAccessTokenは増えない" do
        expect {
          post "/api/auth/session", params: { email: "", password: "password" }, as: :json
        }.not_to change(AccessToken, :count)

        expect(response).to have_http_status(:unauthorized)      
      end     
    end 
  end
end