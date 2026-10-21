require 'rails_helper'

RSpec.describe ExternalBooks::Search, type: :service do
  describe '.call' do

    context '正常系' do
      it '書籍名で検索すると、目的の書籍が候補に含まれる' do
        # 条件：検索して目的の書籍が出る
        # 期待結果：候補を返す
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

        books = ExternalBooks::Search::call(query: "嫌われる勇気")

        expect(books).to eq([
          {
            title: "嫌われる勇気",
            author: "岸見一郎・古賀史健"
          }
        ])
      end

      it '検索結果が0件の場合、空配列を返す' do
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "存在しない書籍12345", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: { items: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        books = ExternalBooks::Search::call(query: "存在しない書籍12345")

        expect(books).to eq([])
      end
    end

    context '異常系' do
      it '外部APIがタイムアウトした場合、検索失敗として処理する' do
        # 条件：外部APIへの通信がタイムアウトする
        # 期待結果：Serviceは外部接続失敗の503例外を返す
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_raise(Net::OpenTimeout)

        expect {
          ExternalBooks::Search.call(query: "嫌われる勇気")
        }.to raise_error(Net::OpenTimeout)
      end

      it 'タイトルが欠落した候補のみ除外し、正常な候補は維持する' do
        #2
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "存在しない書籍12345", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: { items: [
              {
                volumeInfo: {
                  title: "嫌われる勇気",
                  authors: ["岸見一郎", "古賀史健"]
                }
              },
              {
                volumeInfo: {
                  authors: ["著者A"]
                }
              }
            ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        books = ExternalBooks::Search::call(query: "存在しない書籍12345")

        expect(books).to eq([
          {
            title: "嫌われる勇気",
            author: "岸見一郎・古賀史健"
          }
        ])
      end

      it '著者が欠落していても、authorがnilの候補として返す' do
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: {
              items: [
                {
                  volumeInfo: {
                    title: "嫌われる勇気"
                  }
                }
              ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        books = ExternalBooks::Search::call(query: "嫌われる勇気")

        expect(books).to eq([
          {
            title: "嫌われる勇気",
            author: nil
          }
        ])

      end
      it '外部APIのレスポンスが不正な場合、正常な検索結果として扱わない' do
        # 条件：外部APIへのレスポンスが使えないものであること
        # 期待結果：# 期待結果：ServiceからJSON::ParserErrorが伝播する（502はrequest）
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_return(
            status: 200,
            body: '{invalid json',
            headers: { "Content-Type" => "application/json" }
          )
        expect {
          ExternalBooks::Search.call(query: "嫌われる勇気")
        }.to raise_error(JSON::ParserError)
      end


      it '外部APIへの接続に失敗した場合、検索失敗として処理する' do
        # 条件：外部apiに接続が失敗
        # 期待結果：Serviceは不正形式の503を返す
        allow(ENV).to receive(:fetch).with("BOOKS_API_KEY").and_return("test-api-key")
        stub_request(:get, "https://www.googleapis.com/books/v1/volumes")
          .with(query: { q: "嫌われる勇気", maxResults: "5", key: "test-api-key" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          ExternalBooks::Search.call(query: "嫌われる勇気")
        }.to raise_error(Errno::ECONNREFUSED)

      end
    end

  end
end