cat > docs/api_spec.md << 'EOF'
## 1. 共通仕様

- Base URL: `/api`
- Format: JSON
- Header:
  - `Content-Type: application/json`
- エラー時:
  - `{"errors": { "field": ["message1", ...] }}`
  - ステータスコードで種類を区別（400/404/422/500）

---

## 2. Books API

### 2.1 本一覧取得

**GET /api/books**

- Request: なし
- Response 200:

```json
[
  { "id": 1, "title": "カラマーゾフの兄弟", "author": "フョードル・ドストエフスキー" },
  { "id": 2, "title": "夜と霧", "author": "ヴィクトール・E・フランクル" }
]