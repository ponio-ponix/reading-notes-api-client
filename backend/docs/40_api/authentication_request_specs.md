# Request Spec Authentication Policy
## 目的
Request spec では、認証そのものの挙動と、各APIの機能仕様を分けて確認する。
すべてのrequest specで毎回ログイン処理を検証すると、各specの責務が曖昧になる。  
そのため、本プロジェクトでは以下の方針でrequest specを分ける。
---
## 基本方針
- 認証そのものの挙動は `authentication_spec` で確認する
- login / logout APIそのものの挙動は `api/auth/session_spec` で確認する
- 各APIのrequest specでは、原則として「認証済みユーザーがいる」前提で機能仕様を確認する
- 通常の機能ごとのrequest specでは、認証フローを毎回検証せず、各specの責務に集中するために認証をstubする
- 実際のBearer Token認証フローを確認する必要があるspecでは、`auth: :real` を使って認証stubを回避する
---
## `authentication_spec` の責務
`authentication_spec` では、保護APIに対するBearer Token認証そのものの挙動を確認する。
確認対象は以下。
- valid Bearer token の場合は `200 OK`
- Authorization header がない場合は `401 Unauthorized`
- 不正なTokenの場合は `401 Unauthorized`
- BearerのみでTokenが空の場合は `401 Unauthorized`
- expired token の場合は `401 Unauthorized`
- revoked token の場合は `401 Unauthorized`
認証失敗時のレスポンス形式は以下。
```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```
---
## `api/auth/session_spec` の責務
`api/auth/session_spec` では、login / logout APIそのものの仕様を確認する。
確認対象は以下。
- login成功時に raw token を返す
- login成功時に `AccessToken` が1件作成される
- login成功時、raw token はレスポンスで返るが、DBにはSHA256 digestのみ保存される
- login失敗時は `401 Unauthorized` を返す
- login失敗時は `AccessToken` が作成されない
- logout成功時に現在のTokenがrevoked状態になる
- logout後、同じTokenで保護APIにアクセスすると `401 Unauthorized` を返す
- Bearer tokenなしでlogoutしようとした場合は `401 Unauthorized` を返す
---
## `auth: :real` の用途
本プロジェクトでは、通常のrequest specで認証済みユーザーをstubする。  
一方、実際のBearer Token認証フローを確認する必要があるspecでは、`auth: :real` を付与する。
`auth: :real` が付与されたspecでは、認証stubを回避し、実際の `Authorization: Bearer <token>` ヘッダーによる認証を確認する。
---
## 各API request spec の責務
Books / Notes / Bulk / Search などの機能ごとのrequest specでは、認証そのものではなく、各APIの仕様を確認する。
例：
- レスポンスステータス
- レスポンスJSONの構造
- validation error
- RecordNotFound時の `404 Not Found`
- 所有権境界
- soft-deleted Book の除外
- Bulk作成時のrollback
- Search条件の挙動
---
## 認証stubを使う理由
各APIのrequest specで毎回実際のログイン処理を通すと、失敗原因が以下のどちらか判別しにくくなる。
- 認証処理の失敗
- 各API本体の仕様違反
そのため、通常の機能specでは認証済みユーザーをstubし、テスト対象をAPI本体の責務に限定する。
```text
authentication_spec
→ 保護APIに対するBearer Token認証そのものを確認する
api/auth/session_spec
→ login / logout APIそのものを確認する
books_spec / notes_spec / bulk_spec / search_spec
→ 認証済みユーザーを前提に、各APIの仕様を確認する
```
---
## Books request spec の方針
`books_spec` では、認証済みユーザーがいる前提で、Books APIのレスポンス構造と所有権スコープを確認する。
特に `GET /api/books` では、以下を確認する。
- response body に認証済みユーザー本人のBookだけが含まれる
- 他ユーザーのBookは含まれない
- soft-deleted Book は含まれない
- 配列は `created_at` 降順で返る
- Bookが存在しない場合は空配列を返す
所有権境界は、`current_user.books` を起点にした取得によって担保する。
---
## 追加するとよい認証spec
現在のspecに加えて、以下のケースも確認すると認証仕様としてより明確になる。
### `authentication_spec` に追加候補
- `returns 401 when Authorization scheme is not Bearer`
- `returns 401 when Authorization header has lowercase bearer only if implementation does not allow it`
- `returns 401 when token digest does not match any active AccessToken`
### `api/auth/session_spec` に追加候補
- `revokes current token on logout`
- `returns { ok: true } on successful logout`
- `returns 401 when logout token is invalid`
- `returns 401 when logout token is expired`
- `returns 401 when logout token is already revoked`
- `does not create AccessToken when password is wrong`
- `does not create AccessToken when email is blank`
- `does not store raw token in access_tokens.token_digest`
---
## まとめ
本プロジェクトのrequest specでは、認証と機能仕様を混ぜずに分離して確認する。
- 認証仕様は `authentication_spec`
- login / logout API仕様は `api/auth/session_spec`
- 各APIの機能仕様はそれぞれのrequest spec
- 通常の機能specでは認証をstub
- 実認証フローが必要な場合のみ `auth: :real`
この方針により、specの責務を明確にし、認証・所有権・API本体の不具合を切り分けやすくしている。