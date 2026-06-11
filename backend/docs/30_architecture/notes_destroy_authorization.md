# Notes Destroy Authorization

## 目的

`DELETE /api/books/:book_id/notes/:id` では、ログイン中ユーザーが所有する未削除Bookに紐づくNoteだけを削除対象にする。

Noteをグローバルな `Note.find(params[:id])` で取得すると、他ユーザーのNote IDを直接指定された場合に、所有者境界を越えて操作できる可能性がある。  
そのため、本APIではBookの所有者境界を先に確認し、そのBookに紐づくNoteだけを削除対象にする。

---

## 認可方針

Note削除では、以下の順序で対象リソースを取得する。

1. Bearer Token によりログイン中ユーザーを特定する
2. `current_user.books.alive.find(params[:book_id])` により、ログイン中ユーザーが所有する未削除Bookだけを取得する
3. 取得済みBookに紐づくNoteから `params[:id]` のNoteを取得する
4. 見つかったNoteのみ削除する

この方針により、Note単体をグローバルに検索しない。

---

## 境界条件

以下の場合は `404 Not Found` として扱う。

- Bookが存在しない
- Bookが削除済み
- Bookが他ユーザー所有
- Noteが存在しない
- Noteが指定Bookに紐づいていない

レスポンスは共通エラー形式に従う。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

存在しない場合と所有権がない場合を区別しないことで、リソースの存在有無や所有関係を外部に露出しない。

---

## 期待する動作

- 自分のBookに紐づくNoteは削除できる
- 他ユーザーのBookに紐づくNoteは削除できない
- 他ユーザーのBook IDを指定した場合は `404 Not Found`
- 自分のBook IDを指定しても、そのBookに存在しないNote IDなら `404 Not Found`
- 削除済みBookに対するNote削除は `404 Not Found`

---

## 実装上の要点

Notes系APIでは、Controller入口でBookの境界を確定する。

```ruby
book = current_user.books.alive.find(params[:book_id])
note = book.notes.find(params[:id])
note.destroy!
```

この構成により、所有者境界は `current_user.books` で担保し、Note削除対象は取得済みBookの配下に限定する。

---

## 確認すべきspec

- `deletes own note`
- `returns 404 when book belongs to another user`
- `returns 404 when note belongs to another book`
- `returns 404 when book is soft-deleted`
- `returns 401 without Bearer token`