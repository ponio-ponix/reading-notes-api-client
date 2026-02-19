# Invariants (不変条件) – Notes Domain

本アプリの品質を支える「守るべき前提条件・壊れてはならない状態」の定義。

ユースケース単位のロジックよりも長寿命であり、
データ整合性・トランザクション境界・API 一貫性を保証する。

本ドキュメントの内容は **DB 制約・Model validation と常に一致する必要がある**。

---

# 1. モデル不変条件（Model-Level Invariants）

## (0) Book.title は必須である
- `NULL` 不可（DB NOT NULL 制約: `20260219104121_make_books_title_not_null.rb`）
- 空文字は許容しない（Model: `validates :title, presence: true`）

**Why**
書籍タイトルは Book を識別する最低限の情報であり、省略を許可しない。

---

## (1) Note は必ず Book に属する
- `note.book_id` は **NULL 不可**
- 存在しない `book_id` を参照しない（FK 制約）

**Why**
整理の単位が Book であるため、孤児 Note を許可しない。
DB レベルで整合性を保証する。

---

## (2) quote は必須である
- `NULL` 不可
- 空文字は許容しない
- **最大 1000 文字**（DB CHECK 制約）

**Why**
引用が存在しない Note は意味を持たない。
過剰な長文による DB 汚染を防ぐ。

---

## (3) page は必須であり 1 以上の整数
- `NULL` 不可（DB NOT NULL）
- **必ず `>= 1`**（DB CHECK 制約）

**Why**
引用位置は Note の基本属性であり必須情報。
不正値（0・負数）を DB に保存させない。

---

## (4) memo は任意だが上限がある
- `NULL` 許容
- **最大 2000 文字**（DB CHECK 制約）

**Why**
補足情報として任意入力を許可しつつ、
無制限入力による肥大化を防ぐ。

---

## (5) Note の保存は常にアトミック
- 途中状態（部分更新・不完全保存）は存在しない
- 永続化はトランザクション境界内で完結する

**Why**
「引用 + メモ」は不可分の単位であり、
整合性が崩れると意味を失う。

---

---

# 2. API 不変条件（API-Level Invariants）

Bulk Create Notes を中心とした API 振る舞いの保証。

---

## (1) 1リクエスト = 1トランザクション
- Service Layer 内で `ActiveRecord::Base.transaction` を使用
- トランザクション境界は **notes の insert 全体**

**Why**
atomicity（不可分性）を保証するため。

---

## (2) 全件成功 or 全件失敗（All-or-Nothing）
- 1件でも validation / DB エラーがあれば **全ロールバック**
- DB に中途半端な保存状態は残らない

**Why**
UX とデータ整合性の両方を守る最重要条件。

---

## (3) エラーは失敗位置を特定可能
Bulk API の 422 は以下構造：

```json
{
  "errors": [
    { "index": 0, "messages": ["page must be greater than or equal to 1"] }
  ]
}
```

**Why**
部分成功を禁止しつつ、
ユーザーが修正可能な情報を返す必要がある。

---

## (4) 二重送信でも破壊的副作用を起こさない
- 同一リクエストが複数回送信されてもクラッシュしない
- 完全な idempotency は MVP 範囲外

**Why**
実運用の「保存ボタン連打」に耐える最低限の安全性。

---

---

# 3. 検索（SearchNotes）の不変条件

## (1) 検索対象は常に Book 内に限定
- `WHERE notes.book_id = ?` は常に適用

## (2) ページ範囲検索は閉区間
例：page_from=10, page_to=20 → 10〜20 をすべて含む

## (3) 結果順序は常に created_at DESC
- 並び順は必ず安定
- UI 表示順と一致

**Why**
読書履歴は「新 → 旧」で確認されるため。

---

# 4. 将来拡張を壊さないための不変条件

## (1) Note の意味は「引用の最小単位」のまま固定
- タグ・章などは外部テーブルで表現
- Note 自体の責務は増やさない

## (2) Book は Note の最小グループ境界
- multi-user / 共有機能追加後も境界は維持

## (3) ビジネスロジックは Service 層に配置
- Model へ過剰な責務集中を防ぐ
- トランザクション制御は Service が担う

---

# 結論

この Invariants により保証される：

- DB 制約と完全一致したモデル整合性
- Bulk Create の厳密なトランザクション保証
- 検索結果の順序安定性
- 将来拡張でも壊れない責務分離

本ドキュメントは Notes ドメインの SSOT（Single Source of Truth）として扱う。
