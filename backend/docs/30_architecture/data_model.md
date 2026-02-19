# Data Model (MVP Version)

本アプリの目的は「引用＋ページ情報を爆速でインボックス化し、あとで整理可能にする」ことである。  
そのため、データモデルは極力シンプルに保つ。

---

## 1. ER 図（MVP）

Book (1) —— (N) Note

---

## 2. Book モデル

### 必要理由
- 複数冊の書籍を扱う前提のため
- Note をグルーピングする最小単位として必須

### バリデーション
- title: presence: true（DB NOT NULL 制約あり: `20260219104121_make_books_title_not_null.rb`）
- author: 任意

### 拡張余地
- note_count のキャッシュカラム（MVP では不要）
- last_noted_at（Bulk Create 時に更新できる設計も可能）

---

## 3. Note モデル

### 目的
引用メモの最小単位。  
UI とトランザクション境界の中心となるモデル。

### カラム仕様（MVP）
| カラム | 型 | 制約 | 目的 |
|-------|----|------|------|
| book_id | bigint | not null, FK (on_delete: :restrict) | 親BookへのFK |
| page | integer | not null, CHECK (page >= 1) | ページ番号 |
| quote | text | not null, CHECK (char_length <= 1000) | 引用文（最大1000文字） |
| memo | text | null allowed, CHECK (char_length <= 2000) | 補足メモ（最大2000文字） |

---

## 4. バリデーション方針（MVP）

### quote
- 必須（NOT NULL）
- 最大文字数：**1000文字**（DB CHECK 制約）

### page
- 必須（NOT NULL）
- 値は `>= 1`（DB CHECK 制約）

### memo
- 任意（NULL 許容）
- 最大文字数：**2000文字**（DB CHECK 制約）

---

## 5. 重複の扱い（MVP）

### 同じ page + quote が複数存在するのを許容する  
理由：
- 読書中の入力で「重複してしまうこと」は自然にありうる  
- ユニーク制約は UX を阻害する  
- 後処理（整理機能）で対応できる

---

## 6. Bulk Create を前提にしたモデル設計上の注意

### 1. Note は **1件ずつ save する** 設計のままで良い
Bulk Create はトランザクション境界の話であって、  
Note モデルに特別な insert 構造を持たせる必要はない。

### 2. モデルに副作用は持たせない
- トランザクション制御は Service Layer に集約する  
- Note.save 内で複雑なロジックを発火させない

---

## 7. 将来拡張に備えた余白

以下は MVP では入れないが、データモデルが壊れないように配慮する。

- Tag テーブル（多対多）
- Section / Chapter テーブル（自動構造化）
- note_count のキャッシュ
- 同期用の revision カラム

どれも現行の Book / Note モデルを壊さずに追加可能。

---

## 結論

MVP のデータモデルは **Book と Note の2テーブルだけ**。  
不変条件とトランザクション設計をアピールするなら、  
この最小構成が “一番強く・綺麗に・破綻せず” まとまる。

