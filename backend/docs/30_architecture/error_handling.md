# Error Handling

## 目的

本APIでは、例外処理を `ApplicationController` の `rescue_from` に集約し、  
API全体で一貫したHTTPステータスとJSONレスポンスを返す。

各Controllerに個別の `rescue` を書くのではなく、  
例外クラスごとの扱いを一箇所で管理することで、エラー処理のばらつきを防ぐ。

---

## なぜ `rescue_from` で統一するのか

Rails の `rescue_from` は、Controller内で発生した特定の例外を捕捉し、  
指定したメソッドやProcで処理するための仕組みである。

Rails Guides でも、`rescue_from` は特定の例外を捕捉して別の処理を行う方法として説明されており、  
そのController全体およびサブクラスに対して適用できる。  
また、Rails APIでは `ActionController::Rescue` がControllerに `rescue_from` を提供し、設定された例外を処理する役割を持つと説明されている。

本APIではこの仕組みを `ApplicationController` に集約し、  
例外をHTTPステータスと共通JSONレスポンスに変換している。

これにより、以下を実現する。

- Controllerごとのエラーレスポンス形式のばらつきを防ぐ
- `400` / `401` / `404` / `422` / `500` の対応を一箇所で管理する
- Controller本体を正常系の処理に集中させる
- Rails標準例外をAPI仕様に合わせて変換する
- 想定外エラーを誤ってクライアントエラーに落とさず、バグとして検知する

つまり、`rescue_from` による統一は、単なる例外処理の共通化ではなく、  
**API全体の失敗時の契約を一箇所で管理するための設計**である。

参考:
- Rails API: [`ActiveSupport::Rescuable#rescue_from`](https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from)
- Rails API: [`ActionController::Rescue`](https://api.rubyonrails.org/classes/ActionController/Rescue.html)

---

## `rescue_from` による一元化

各Controllerでは、原則として個別に `rescue` を書かない。

例外は `ApplicationController` でまとめて捕捉し、  
HTTPステータスとJSONレスポンスに変換する。

```ruby
class ApplicationController < ActionController::API
  rescue_from ApplicationErrors::BadRequest, with: :render_bad_request
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable_entity
  rescue_from Notes::BulkCreate::BulkInvalid, with: :render_bulk_invalid
end
```

共通レスポンス例:

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

## 例外とステータスコードの対応

| Exception | Status | Meaning |
|----------|--------|---------|
| `ApplicationErrors::BadRequest` | 400 | アプリが意図して検出した不正リクエスト |
| `ActionController::ParameterMissing` | 400 | 必須パラメータ不足 |
| `ActiveRecord::RecordNotFound` | 404 | 対象リソースが存在しない、またはアクセス可能範囲に存在しない |
| `ActiveRecord::RecordInvalid` | 422 | モデルバリデーション失敗 |
| `ActiveRecord::RecordNotDestroyed` | 422 | 削除処理失敗 |
| `Notes::BulkCreate::BulkInvalid` | 422 | Bulk Createの入力行単位バリデーション失敗 |
| DB制約違反 | 422 | DBレベルの整合性違反 |
| `StandardError` | 500 | 想定外エラー。本番環境でのみ最終受け皿として扱う |

---

## 4xx / 5xx の境界

本APIでは、`4xx` と `5xx` を以下の基準で分ける。

- `4xx`
  - クライアントのリクエスト内容に問題がある
  - アプリ側が意図して検出した失敗
  - 例: 必須パラメータ不足、存在しないリソース、validation失敗

- `5xx`
  - サーバ側の想定外エラー
  - 実装バグや未考慮ケースとして検知すべき失敗

特に、Ruby / Rails / gem の一般例外を安易に `400 Bad Request` に変換しない。  
たとえば `ArgumentError` は入力ミスだけでなく実装バグでも発生するため、  
一律で `400` に落とすと、本来検知すべきバグがクライアントエラーに埋もれる。

そのため、`400` にしたい場合は、入力検証の段階でアプリ固有例外を明示的に投げる。

```ruby
raise ApplicationErrors::BadRequest, "Bad request"
```

---