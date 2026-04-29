require 'rails_helper'

RSpec.describe "Api::Users", type: :request do
  #すでに登録してあるemailで再度登録しようとした場合の先に用意しておくuserなのでランダムにしない
  let!(:example_user) do
    User.create!(
      email: "abab@example.com",
      password: "password"
    )
  end

  describe "POST /api/users" do

    context "正常系" do
      it "emailとパスワードが登録できること" do
        post "/api/users",
          params: { user: { name: "test", email: "notes-spec-#{SecureRandom.hex(4)}@example.com", password: "password", password_confirmation: "password"}}, 
          as: :json
          expect(response).to have_http_status(:created)
      end
    end

    context "異常系" do

      context "必須" do
        it "emailが空文字" do
   
          post "/api/users",
                params: { user: {email: "", password: "password"}},
                as: :json
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
        it "パスワードが空文字" do
          post "/api/users",
              params: { user: {email: "note-spec-#{SecureRandom.hex(4)}@example.com", password: ""}},
              as: :json
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
       
        it "emailがnil" do
       
          post "/api/users",
                params: { user: {email: nil, password: "password" }},
                as: :json
    
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
        it "パスワードがnil" do
       
          post "/api/users",
                params: { user: {email: "note-spec-#{SecureRandom.hex(4)}@example.com", password: nil }},
                as: :json
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
        it "emailのキー自体がない" do
        
          post "/api/users",
                params: { user: {password: "password"} },
                as: :json
    
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
        it "パスワードのキー自体がない" do
        
          post "/api/users",
                params: { user: {email: "note-spec-#{SecureRandom.hex(4)}@example.com"}},
                as: :json
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
      context "重複" do
        it "すでに登録してあるemailで再度登録しようとした場合" do
      
          post "/api/users",
                params: { user: {email: "abab@example.com", password: "password"}},
                as: :json
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "形式不正" do
        it "emailの形式不正" do
          post "/api/users",
            params: { user: {email: "note-spec-#{SecureRandom.hex(4)}example.com", password: "password"}},
            as: :json
    
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
