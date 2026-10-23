# Reading Notes Backend API

**Ruby on Rails / PostgreSQL / RSpec**

読書メモ管理用のRails APIです。既存バックエンドの保守・機能追加を意識し、**既存機能の調査・改善、外部API連携、異常系テスト**に取り組みました。

## Development Examples

### 1. 既存APIの改善 — 所有者境界・論理削除

**課題：** Bookを扱うAPIごとに、所有権・削除状態の確認方法が統一されていませんでした。

**対応：** `current_user.books.alive.find(...)` を取得起点に統一し、他ユーザー・削除済みBookへのアクセスを404として扱う構造へ整理しました。

**確認先：** [PR #27：実装・RSpec](https://github.com/ponio-ponix/reading-notes-api-client/pull/27)

### 2. 既存APIへの機能追加 — Google Books API連携

**課題：** 書籍検索機能の追加にあたり、外部サービスの障害時にも想定したレスポンスを返す必要がありました。

**対応：** タイムアウト・接続拒否・429/500/503・不正JSONをWebMockで再現し、503を返す動作をRSpecで検証。検索処理とDB保存も分離し、既存のBook登録APIを再利用しました。

**確認先：** [Issue #35：要求・仕様](https://github.com/ponio-ponix/reading-notes-api-client/issues/35) / [PR #36：実装・RSpec](https://github.com/ponio-ponix/reading-notes-api-client/pull/36)

## Other Implementations

| 領域 | 実装・検証内容 |
|---|---|
| 認証 | Bearer Token認証、Tokenのdigest保存・失効管理 |
| データ整合性 | Rails validation・DB制約（NOT NULL / FK / CHECK） |
| 一括登録 | transactionによる全件成功・全件失敗 |
| テスト | RSpecによる正常系・異常系・回帰確認 |

## Technical Review

実装内容や設計判断の詳細は、Backend READMEにまとめています。

- **設計判断**：なぜその構成・実装方法を選んだのか
- **実装コード**：対応するController・Service・Model
- **テスト**：正常系・異常系を検証したRSpec
- **動作確認**：本番環境でのAPI確認手順

**[Backend READMEを見る — 設計判断・実装・テストの詳細](https://github.com/ponio-ponix/reading-notes-api-client/blob/main/backend/README.md)**

## Production / Repository

- [本番環境：Health Check](https://backend-withered-voice-4962.fly.dev/healthz)
- [Canonical Repository](https://github.com/ponio-ponix/reading-notes)

## License

MIT License

Copyright (c) 2026 Kaoru Matsumoto