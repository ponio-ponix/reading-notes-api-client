require 'rails_helper'

RSpec.describe 'External Book Searches API', type: :request do
  let!(:user) do
    User.create!(
      email: "note-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end
  
  describe 'GET /api/external_book_searches' do

    context '正常系' do
        before do
          stub_authentication(user)
        end
      it '検索結果が0件の場合、200 OKと空配列を返す' do
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: { items: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        
        get "/api/external_book_searches", params: { query: "嫌われる勇気" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
        
      end

      it '検索するだけではBookレコードを作成しない' do
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: {
              items: [
                {
                  volumeInfo: {
                    title: "嫌われる勇気",
                    authors: ["岸見一郎", "古賀史健"]
                  }
                }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        expect {
          get "/api/external_book_searches", params: { query: "嫌われる勇気" }
        }.not_to change(Book, :count)
      end
    end

    context '異常系' do
        before do
          stub_authentication(user)
        end
      it '検索パラメータが不正な場合、外部APIを呼ばずに拒否する' do
        # 条件：パラメーターの内容が不正なとき
        # 期待結果：
        get "/api/external_book_searches", params: { query: "" }
        expect(response).to have_http_status(:bad_request)
      end

      it '外部APIがタイムアウトした場合、503を返す' do
      # 条件：検索Serviceでタイムアウトが発生する
      # 期待結果：HTTP 503と検索失敗のJSONを返す
      end
    end

    context '異常系（スタブなし）' do
      it '未認証ユーザーの場合、401 Unauthorizedを返す', auth: :real do

        get "/api/external_book_searches", params: { query: "嫌われる勇気" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
