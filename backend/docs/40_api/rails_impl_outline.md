

# Rails Implementation Outline（API / Controller / Service）

本ドキュメントでは、API 仕様を Rails 実装に落とし込むための「雛形方針」をまとめる。

---

## 1. Controller 構成

### 1.1 Books

- クラス: `Api::BooksController`
- エンドポイント:
  - `GET /api/books` → `#index`

```rb
module Api
  class BooksController < ApplicationController
    def index
      # soft-delete 対応: Book.alive スコープで削除済みを除外
      books = Book.alive.order(created_at: :desc)

      render json: books.as_json(only: [:id, :title, :author])
    end
  end
end

```
---

### 1.2 Notes（単一作成・削除・検索）

#### なぜ検索（index）を分離したか

- NotesController を「単一 CRUD（create / destroy）」に寄せて責務を単純化
- 検索はパラメータ正規化・クエリ組み立て・ページネーション等で肥大化しやすい
- SearchController + Service に分離することで責務境界が明確になる

#### エンドポイント対応

| HTTP   | Path                          | Controller#Action                  |
|--------|-------------------------------|------------------------------------|
| GET    | `/api/books/:book_id/notes`   | `Api::NotesSearchController#index` |
| POST   | `/api/books/:book_id/notes`   | `Api::NotesController#create`      |
| DELETE | `/api/notes/:id`              | `Api::NotesController#destroy`     |

#### Api::NotesController（単一作成・削除）

```rb
module Api
  class NotesController < ApplicationController

    before_action :set_book, only: [:create]

    # Create Note
    #
    # Success:
    # - 201 Created + note json
    #
    # Failure:
    # - ActiveRecord::RecordNotFound (Book not found / soft-deleted) -> 404 (handled in ApplicationController)
    # - ActiveRecord::RecordInvalid (validation failed) -> 422
    #   - response: { errors: record.errors.full_messages }  ※SSOT: docs/40_api/api_overview.md

    def create
      note = @book.notes.create!(note_params)
      render json: note.as_json(only: [:id, :book_id, :page, :quote, :memo, :created_at]),
             status: :created
    end

    def destroy
      note = Note.find(params[:id])
      note.destroy!
      head :no_content
    end

    private

    def set_book
      @book = Book.alive.find(params[:book_id])
    end

    def note_params
      params.require(:note).permit(:page, :quote, :memo)
    end
  end
end
```

#### Api::NotesSearchController（検索）

```rb
module Api
  class NotesSearchController < ApplicationController
    # Book の存在確認は Notes::SearchNotes 側で行う（Controller で二重に DB を叩かない）
    def index
      notes, meta = Notes::SearchNotes.call(
        book_id:   params[:book_id],
        query:     params[:q],
        page_from: params[:page_from],
        page_to:   params[:page_to],
        page:      params[:page],
        limit:     params[:limit]
      )

      render json: {
        notes: notes.as_json(only: [:id, :book_id, :page, :quote, :memo, :created_at]),
        meta:  meta
      }
    end
  end
end
```


⸻

1.3 NotesBulk（Bulk Create）
	•	クラス: Api::NotesBulkController
	•	エンドポイント:
	•	POST /api/books/:book_id/notes/bulk → #create

```rb
class Api::NotesBulkController < ApplicationController


  # Book の存在確認は Notes::BulkCreate 側で行う（Controller で二重にDBを叩かない）
  def create
    notes = Notes::BulkCreate.call(
      book_id: params[:book_id],
      notes_params: notes_params
    )

    render json: {
      notes: notes.as_json(only: [:id, :page, :quote, :memo, :created_at]),
      meta:  { created_count: notes.size }
    }, status: :created
  end

  private

  # HTTP レイヤで Request の形だけをチェックする。
  # notes が配列であること、各要素が permit できる形であることを保証する。
  #
  # 形が壊れている場合は例外を投げ、
  # 400 にするかどうかなどの HTTP レスポンスは
  # ApplicationController 側の rescue に任せる。
  #
  # バリデーションや一括作成のルールは Service に寄せる。

  def notes_params
    raw = params[:notes]
    raise ApplicationErrors::BadRequest, "notes must be provided" if raw.nil?
    raise ApplicationErrors::BadRequest, "notes must be an array" unless raw.is_a?(Array)
  
    raw.map.with_index do |note, i|
      raise ApplicationErrors::BadRequest, "notes[#{i}] must be an object" unless note.is_a?(ActionController::Parameters)
      note.permit(:page, :quote, :memo).to_h
    end
  end

end
```


⸻

2. Service / UseCase の雛形

2.1 Notes::SearchNotes

# app/services/notes/search_notes.rb

```rb
# app/services/notes/search_notes.rb
module Notes
  class SearchNotes
    DEFAULT_LIMIT = 50
    MAX_LIMIT     = 200

    # ==== 公開インターフェース ====
    # Controller からはここだけ呼ぶ
    def self.call(book_id:, query: nil, page_from: nil, page_to: nil, page: nil, limit: nil)
      params = normalize_params(
        book_id: book_id,
        query: query,
        page_from: page_from,
        page_to: page_to,
        page: page,
        limit: limit
      )
      book = Book.alive.find(params[:book_id])
      # ① 入力を Service 内部用に正規化

      # ② 検索条件を組み立てる
      rel = build_scope(book, params)

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
      raise ApplicationErrors::BadRequest, "book_id must be a numeric string" unless book_id.to_s =~ /\A\d+\z/

      if page.present? && page.to_s !~ /\A\d+\z/
        raise ApplicationErrors::BadRequest, "page must be an integer or nil"
      end
    
      if limit.present? && limit.to_s !~ /\A\d+\z/
        raise ApplicationErrors::BadRequest, "limit must be an integer or nil"
      end
    
      if page_from.present? && page_from.to_s !~ /\A\d+\z/
        raise ApplicationErrors::BadRequest, "page_from and page_to must be integers"
      end
    
      if page_to.present? && page_to.to_s !~ /\A\d+\z/
        raise ApplicationErrors::BadRequest, "page_from and page_to must be integers"
      end

      page_i  = page.to_i
      page_i  = 1 if page_i <= 0
      page_from_i  = page_from.present? ? page_from.to_i : nil
      page_to_i    = page_to.present?   ? page_to.to_i   : nil
      limit_i      = normalize_limit(limit)

      if page_from_i && page_to_i && page_from_i > page_to_i
        raise ApplicationErrors::BadRequest, "page_from must be less than or equal to page_to"
      end
    

      {
        book_id: book_id.to_i,
        query:     query&.to_s&.strip&.presence,
        page_from: page_from_i,
        page_to:   page_to_i,
        page:      page_i,
        limit:     limit_i
      }
    end
    private_class_method :normalize_params

    # 正規化済み params から ActiveRecord::Relation を作る
    def self.build_scope(book, params)
      rel = book.notes

      if params[:page_from]
        rel = rel.where("page >= ?", params[:page_from])
      end

      if params[:page_to]
        rel = rel.where("page <= ?", params[:page_to])
      end

      if params[:query].present?
        tokens = params[:query].split(/\s+/)
        tokens.each do |token|
          pattern = "%#{token}%"
          rel = rel.where("quote ILIKE :pattern OR memo ILIKE :pattern", pattern: pattern)
        end
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

```


⸻

2.2 Notes::BulkCreate

（中身はすでに実装済みのやつで OK。ここでは「アウトライン」として位置づけだけ記載。）

# app/services/notes/bulk_create.rb
```rb
module Notes
  class BulkCreate
    class BulkInvalid < StandardError
      attr_reader :errors
      def initialize(errors:)
        @errors = errors
        super("bulk create invalid")
      end
    end

    MAX_NOTES_PER_REQUEST = 20

    def self.call(book_id:, notes_params:)
      unless notes_params.is_a?(Array) && notes_params.any?
        raise ApplicationErrors::BadRequest, "notes must be a non-empty array"
      end
      if notes_params.size > MAX_NOTES_PER_REQUEST
        raise ApplicationErrors::BadRequest, "too many notes (max #{MAX_NOTES_PER_REQUEST})"
      end

      book  = Book.alive.find(book_id) 

      notes  = []
      errors = []

      # 全行のエラーを返すため先に検証し、トランザクションは書き込みだけに絞る
      notes_params.each_with_index do |raw_attrs, i|
        attrs = raw_attrs.to_h.symbolize_keys.slice(:page, :quote, :memo)
        note  = book.notes.build(attrs)

        if note.valid?
          notes << note
        else
          errors << { index: i, messages: note.errors.full_messages }
        end
      end

      raise BulkInvalid.new(errors: errors) if errors.any?

      ActiveRecord::Base.transaction do
        notes.each(&:save!)
      end

      notes
    end
  end
end
```

⸻
