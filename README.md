# Reading Notes Backend API

読書中の引用・メモを管理する、Ruby on Rails API mode製のバックエンドAPIです。

単なるCRUDではなく、以下を実装し、ユーザー単位のデータ保護と不正データの永続化防止を重視しています。

- Bearer Token認証
- ログイン中ユーザーを起点とした所有者境界
- Rails validationとDB制約によるデータ整合性
- 一括登録時の全件成功・全件失敗
- RSpecによる正常系・異常系・回帰テスト


## Technical Highlights

| 防ぐ問題 | 設計・実装 |
|---|---|
| raw tokenのDB流出 | クライアントにはraw tokenを返し、DBにはSHA256 digestのみ保存 |
| 他ユーザー・削除済みBookへのアクセス | 所有者境界として `current_user.books.alive.find(...)` を起点に取得し、対象外は404として処理 |
| 不正データの永続化 | Rails validationに加えてNOT NULL・FK・CHECK制約を設定 |
| 一括登録時の部分保存 | transactionにより全件成功または全件失敗を保証 |
| エラーレスポンスのばらつき | `ApplicationController`で主要例外を共通JSON形式へ変換 |

## For Technical Reviewers

Backend READMEでは、以下を確認できます。

- 認証・所有者境界・DB制約の設計判断
- 対応するController・Model・migration・RSpec
- 本番環境での3分評価ルート

**[Backend READMEで実装・設計・RSpecを確認する](backend/README.md)**

## Tech Stack

- Ruby 3.2.2
- Ruby on Rails 8.0.4（API mode）
- PostgreSQL 16
- RSpec
- Docker / Docker Compose
- Fly.io
- Neon

## Production

### Health Check

```bash
curl -i https://backend-withered-voice-4962.fly.dev/healthz
```

## Repository

Canonical repository:

https://github.com/ponio-ponix/reading-notes

This repository is the canonical and actively maintained source.

## License

MIT License

Copyright (c) 2026 Kaoru Matsumoto