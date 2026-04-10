require "rails_helper"

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
    end



  end
end