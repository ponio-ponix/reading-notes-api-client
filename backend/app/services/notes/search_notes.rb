# app/services/notes/search_notes.rb
module Notes
  class SearchNotes
    DEFAULT_LIMIT = 50
    MAX_LIMIT     = 200

    def self.call(book_id:, query: nil, page_from: nil, page_to: nil, page: nil, limit: nil)
      # 1. ベーススコープ
      rel = Note.where(book_id: book_id)

      # 2. ページ範囲フィルタ
      if page_from.present?
        rel = rel.where("page >= ?", page_from.to_i)
      end

      if page_to.present?
        rel = rel.where("page <= ?", page_to.to_i)
      end

      # 3. キーワード検索（quote / memo）
      if query.present?
        q = "%#{query.strip}%"
        rel = rel.where("quote ILIKE :q OR memo ILIKE :q", q: q)
      end

      # 4. 件数カウント（ページネーション前）
      total_count = rel.count

      # 5. page / limit 決定
      page = page.to_i
      page = 1 if page <= 0

      per = normalize_limit(limit)
      offset = (page - 1) * per

      # 6. 実際のレコード
      records = rel
        .order(created_at: :desc)
        .offset(offset)
        .limit(per)

      # 7. meta 情報
      meta = {
        total_count: total_count,
        page:        page,
        limit:       per,
        total_pages: (total_count.to_f / per).ceil
      }

      # 8. 2つ返す
      [records, meta]
    end

    def self.normalize_limit(raw)
      n = raw.to_i
      return DEFAULT_LIMIT if n <= 0
      return MAX_LIMIT     if n > MAX_LIMIT
      n
    end
    private_class_method :normalize_limit
  end
end