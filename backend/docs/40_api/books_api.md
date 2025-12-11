
---

## 2. Books API



### 2.1 本一覧取得

### Endpoint
**GET /api/books**

- Request: なし
- Response 200:

```json
[
  { "id": 1, "title": "カラマーゾフの兄弟", "author": "フョードル・ドストエフスキー" },
  { "id": 2, "title": "夜と霧", "author": "ヴィクトール・E・フランクル" }
]
```






---

## 3. スタックフレームとこの API の紐付け


- 「1 HTTP リクエストを 1 スタックフレームだと見なして設計」
  - 引数 = パラメータ（`book_id`, `q`, `page`, `per`）
  - 関数本体 = `Notes::SearchNotes.call(...)`
  - 戻り値 = `notes` + `meta`
- 「Controller にロジックを溜めず、関数っぽい Service に寄せることで、
  スタックフレームの考え方（入出力の明示、責務の分離）を Rails の設計に落とし込み」