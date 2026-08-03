# Reading Notes Backend API

読書中の引用・メモを管理する、Ruby on Rails API mode製のバックエンドAPIです。

単なるCRUDではなく、以下を実装し、ユーザー単位のデータ保護と不正データの永続化防止を重視しています。

- Bearer Token認証
- ログイン中ユーザーを起点とした所有者境界
- Rails validationとDB制約によるデータ整合性
- 一括登録時の全件成功・全件失敗
- RSpecによる正常系・異常系・回帰テスト

## Development Background

このAPIは読書メモ管理機能から開発を開始しました。

機能追加を進める中で、単純に機能を増やすだけではなく、
変更時の影響範囲や既存機能との整合性を確認しながら改善を行いました。

### Change Case: Soft Delete / Access Boundary Improvement

#### 課題

既存APIを調査した結果、同じBookを扱う処理でも、
Book取得や所有権確認の方法が統一されていませんでした。

この状態では、今後API追加や仕様変更を行った際に、
処理ごとに異なる境界ルールが発生する可能性がありました。

#### 判断・対応

新規機能追加を進める前に、各APIで境界確認の方法が分かれたまま機能を増やすと、
後から修正範囲が広がりやすいと考えました。

そのため、変更コストや影響範囲を考慮し、
先にBook取得の入口を整理することを優先しました。

Controller入口で `current_user.books.alive.find(...)` を起点に所有権・削除状態を確認し、
Serviceには確認済みのBookを渡す構造へ整理しました。

また、Book削除は物理削除ではなく論理削除として実装し、
削除後のデータ状態を管理できるようにしました。

#### 価値

既存APIの境界を揃えることで、変更時に影響範囲を把握しやすくし、
今後の仕様変更や機能追加でも、同じ境界ルールを適用しながら
安全に改善を続けられる土台を整えました。

詳細な実装・RSpecは [Backend README](backend/README.md) に整理しています。  
関連PR: [#27 Soft Delete / Access Boundary Improvement](https://github.com/ponio-ponix/reading-notes-api-client/pull/27)

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