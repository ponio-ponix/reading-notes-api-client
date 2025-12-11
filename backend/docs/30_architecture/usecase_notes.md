# Notes UseCase / Controller Responsibility

## GET /api/books/:book_id/notes
Controller:
  - params[:book_id], params[:q], :page_from, :page_to, :page, :limit を受け取る
  - 型・範囲チェック → おかしければ 400
  - Notes::SearchNotes.call(...) を呼ぶ
  - 戻り値 (notes, meta) を JSON に整形して返す

Service: Notes::SearchNotes
  - ドメインロジック担当
    - book存在チェック（なければ NotFound エラー投げる）
    - 検索条件の組み立て
    - ページネーション・total_count 計算
  - Controller に「純粋な Ruby の戻り値」を返す (notes, meta)