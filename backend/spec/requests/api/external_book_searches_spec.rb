require 'rails_helper'

RSpec.describe 'External Book Searches API', type: :request do
  describe 'GET /api/external_book_searches' do

    context '正常系' do
      it '検索結果が0件の場合、200 OKと空配列を返す' do

      end

      it '検索するだけではBookレコードを作成しない' do

      end
    end

    context '異常系' do
      it '検索パラメータが不正な場合、外部APIを呼ばずに拒否する' do
        # 条件：パラメーターの内容が不正なとき
        # 期待結果：
      end

      it '未認証ユーザーの場合、401 Unauthorizedを返す' do
      end
      it '外部APIがタイムアウトした場合、503を返す' do
      # 条件：検索Serviceでタイムアウトが発生する
      # 期待結果：HTTP 503と検索失敗のJSONを返す
      end
    end
  end
end
