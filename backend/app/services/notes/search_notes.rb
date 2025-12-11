# app/services/notes/search_notes.rb
module Notes
  class SearchNotes
    DEFAULT_LIMIT = 50
    MAX_LIMIT     = 200

    # ==== 公開インターフェース ====
    # Controller からはここだけ呼ぶ
    def self.call(book_id:, query: nil, page_from: nil, page_to: nil, page: nil, limit: nil)

      raise ActiveRecord::RecordNotFound, "book not found" unless Book.exists?(id: book_id)
      # ① 入力を Service 内部用に正規化
    
      params = normalize_params(
        book_id: book_id,
        query: query,
        page_from: page_from,
        page_to: page_to,
        page: page,
        limit: limit
      )

      # ② 検索条件を組み立てる
      rel = build_scope(params)

      # ③ 件数カウント
      total_count = rel.count

      # ④ ページネーション適用
      records, meta = paginate(rel, params[:page], params[:limit], total_count)

      [records, meta]
    end

    # ==== ここから下は private：内部実装 ====

    # Controller 由来の値（文字列・nil・変な値）を
    # Service 内部で扱いやすい形にそろえる
    def self.normalize_params(book_id:, query:, page_from:, page_to:, page:, limit:)
      raise ArgumentError, "book_id が数値でない" unless book_id.to_s =~ /\A\d+\z/

      if page.present? && page.to_s !~ /\A\d+\z/
        raise ArgumentError, "page が “整数でも nil でもない"
      end
    
      if limit.present? && limit.to_s !~ /\A\d+\z/
        raise ArgumentError, "limit が “整数でも nil でもない"
      end
    
      if page_from.present? && page_from.to_s !~ /\A\d+\z/
        raise ArgumentError, "page_from / page_to が整数でない"
      end
    
      if page_to.present? && page_to.to_s !~ /\A\d+\z/
        raise ArgumentError, "page_from / page_to が整数でない"
      end

      page_i  = page.to_i
      page_i  = 1 if page_i <= 0
      page_from_i  = page_from.present? ? page_from.to_i : nil
      page_to_i    = page_to.present?   ? page_to.to_i   : nil
      limit_i      = normalize_limit(limit)

      if page_from_i && page_to_i && page_from_i > page_to_i
        raise ArgumentError, "page_from must be <= page_to"
      end
    

      {
        book_id:   book_id,
        query:     query&.to_s&.strip,
        page_from: page_from.present? ? page_from.to_i : nil,
        page_to:   page_to.present?   ? page_to.to_i   : nil,
        page:      page_i,
        limit:     normalize_limit(limit)
      }
    end
    private_class_method :normalize_params

    # 正規化済み params から ActiveRecord::Relation を作る
    def self.build_scope(params)
      rel = Note.where(book_id: params[:book_id])

      if params[:page_from]
        rel = rel.where("page >= ?", params[:page_from])
      end

      if params[:page_to]
        rel = rel.where("page <= ?", params[:page_to])
      end

      if params[:query].present?
        q = "%#{params[:query]}%"
        rel = rel.where("quote ILIKE :q OR memo ILIKE :q", q: q)
      end

      rel
    end
    private_class_method :build_scope

    # ページネーションだけを担当する
    def self.paginate(rel, page, per, total_count)
      offset = (page - 1) * per

      records = rel
        .order(created_at: :desc)
        .offset(offset)
        .limit(per)

      meta = {
        total_count: total_count,
        page:        page,
        limit:       per,
        total_pages: (total_count.to_f / per).ceil
      }

      [records, meta]
    end
    private_class_method :paginate

    # limit の正規化だけ担当
    def self.normalize_limit(raw)
      n = raw.to_i
      return DEFAULT_LIMIT if n <= 0
      return MAX_LIMIT     if n > MAX_LIMIT
      n
    end
    private_class_method :normalize_limit
  end
end