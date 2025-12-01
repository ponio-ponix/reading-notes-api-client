cat > docs/architecture.md << 'EOF'
## 1. システム全体構成

- バックエンド: Ruby on Rails (APIモード)
  - `/api/**` でJSONを返すREST API
- フロントエンド: React + TypeScript (SPA)
  - APIを `fetch` / `axios` で叩くクライアント
- DB: PostgreSQL
- 想定クライアント
  - スマホブラウザ（片手操作前提）
  - PCブラウザ（開発時・管理画面用）

MVPでは認証なし（シングルユーザー前提）。  
後からトークンベース認証を追加できる形だけ意識する。

---

## 2. レイヤー構造（Rails側）

### 2.1 レイヤー一覧

1. **Controller（Presentation層）**
   - HTTPリクエスト → パラメータを受け取る
   - Serviceを呼び出し、戻り値をJSONにして返す
   - ロジックは極力書かない（薄く保つ）

2. **Service / UseCase（アプリケーション層）**
   - 「何をするか」のユースケース単位の処理
     - 例: 「本を登録する」「引用ノートを作成する」
   - 複数のRepositoryを組み合わせる
   - トランザクション境界をここに置く

3. **Repository（DAO層）**
   - DBアクセス専用
   - ActiveRecordモデルを直接触るのはここだけに寄せる
   - 例:
     - `BookRepository`
     - `NoteRepository`
     - `TagRepository`

4. **Domain / Model（ドメイン層 + ActiveRecord）**
   - `Book`, `Note`, `Tag`, `NoteTag`
   - ドメインに近い簡単なバリデーションはモデル側に置いてOK
   - ただし「ユースケース依存のロジック」はServiceに置く

---

## 3. 主なコンポーネント

### 3.1 Controller

- `Api::BooksController`
  - `index` : 本一覧
  - `create`: 本の作成
- `Api::NotesController`
  - `index` : 本ごとのノート一覧
  - `create`: 引用ノートの作成
  - `destroy`: ノート削除

役割:
- パラメータの取り出し・簡単な存在チェック
- Serviceの呼び出し
- HTTPステータス・JSONの組み立て

---

### 3.2 Service / UseCase

例:

- `Books::CreateBookService`
  - 入力: `title`, `author`
  - 処理: バリデーション → `BookRepository` 経由で保存
- `Notes::CreateNoteService`
  - 入力: `book_id`, `page`, `quote`, `memo`, `tags`
  - 処理:
    - トランザクション開始
    - Book存在チェック
    - Note保存
    - Tag作成 or 取得
    - NoteTag紐づけ
    - コミット

---

### 3.3 Repository（DAO）

例:

- `BookRepository`
  - `find(id)`
  - `find_by_title(title)`
  - `create(attrs)`
- `NoteRepository`
  - `find(id)`
  - `find_by_book(book_id)`
  - `create(attrs)`
  - `delete(id)`
- `TagRepository`
  - `find_or_create_by_name(name)`
- `NoteTagRepository`
  - `attach(note_id, tag_id)`
  - `detach(note_id, tag_id)`

**ポイント:**
- Controller/Service は ActiveRecord に直接触らない
- `Repository` を介して DB と会話する構造にしておくことで、
  DAO・トランザクション・SQLの話をしやすくする。

---

## 4. トランザクションと分離レベル

- DB: PostgreSQL（デフォルトの `READ COMMITTED` 前提）
- トランザクションを貼るのは **Service層**

例: `Notes::CreateNoteService` 内

- BEGIN TRANSACTION
  - Note作成
  - Tag作成 or 取得
  - NoteTag関連付け
- COMMIT

---

## 5. エラーハンドリング方針

- バリデーションエラー
  - HTTP 422 (Unprocessable Entity)
  - `{"errors": {...}}` 形式
- リソースがない
  - HTTP 404
- サーバ内部エラー
  - HTTP 500（ログを出す）

---

## 6. 認証 / 認可（MVP）

- MVPではユーザー1人前提で認証なし
- 後から JWT / session 認証を追加する前提で、
  - Controllerで `current_user` 的な注入ポイントだけ用意しておく（ダミー実装でOK）
EOF