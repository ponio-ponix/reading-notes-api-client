

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
      books = Book.order(:id)

      render json: books.as_json(only: [:id, :title, :author])
    end
  end
end


⸻

1.2 Notes（単一作成・削除・検索）
	•	クラス: Api::NotesController
	•	エンドポイント:
	•	GET    /api/books/:book_id/notes → #index
	•	POST   /api/books/:book_id/notes → #create
	•	DELETE /api/notes/:id            → #destroy

module Api
  class NotesController < ApplicationController
    before_action :set_book, only: [:index, :create]

    def index
      notes, meta = Notes::SearchNotes.call(
        book_id:   @book.id,
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

    def create
      note = @book.notes.new(note_params)

      if note.save
        render json: note.as_json(only: [:id, :book_id, :page, :quote, :memo, :created_at]),
               status: :created
      else
        render json: { errors: note.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      note = Note.find_by(id: params[:id])
      return render json: { error: "Not found" }, status: :not_found unless note

      note.destroy
      head :no_content
    end

    private

    def set_book
      @book = Book.find_by(id: params[:book_id])
      unless @book
        render json: { error: "Book not found" }, status: :not_found
      end
    end

    def note_params
      params.require(:note).permit(:page, :quote, :memo)
    end
  end
end


⸻

1.3 NotesBulk（Bulk Create）
	•	クラス: Api::NotesBulkController
	•	エンドポイント:
	•	POST /api/books/:book_id/notes/bulk → #create

module Api
  class NotesBulkController < ApplicationController
    rescue_from Notes::BulkCreate::BulkInvalid, with: :render_bulk_invalid
    rescue_from ArgumentError, with: :render_bad_request

    def create
      notes = Notes::BulkCreate.call(
        book_id:      params[:book_id],
        notes_params: notes_params
      )

      render json: {
        notes: notes.as_json(only: [:id, :book_id, :page, :quote, :memo, :created_at]),
        meta:  { created_count: notes.size }
      }, status: :created
    end

    private

    def notes_params
      params.require(:notes).map do |note|
        note.permit(:page, :quote, :memo)
      end
    end

    def render_bulk_invalid(e)
      render json: {
        errors: [
          { index: e.index, messages: e.messages }
        ]
      }, status: :unprocessable_entity
    end

    def render_bad_request(e)
      render json: { errors: [e.message] }, status: :bad_request
    end
  end
end


⸻

2. Service / UseCase の雛形

2.1 Notes::SearchNotes

# app/services/notes/search_notes.rb
module Notes
  class SearchNotes
    DEFAULT_PAGE  = 1
    DEFAULT_LIMIT = 20
    MAX_LIMIT     = 50

    def self.call(book_id:, query:, page_from:, page_to:, page:, limit:)
      new(book_id:, query:, page_from:, page_to:, page:, limit:).call
    end

    def initialize(book_id:, query:, page_from:, page_to:, page:, limit:)
      @book_id   = book_id
      @query     = query.presence
      @page_from = page_from
      @page_to   = page_to
      @page      = (page.presence || DEFAULT_PAGE).to_i
      @limit     = (limit.presence || DEFAULT_LIMIT).to_i
    end

    def call
      raise ArgumentError, "page must be >= 1"  if @page < 1
      raise ArgumentError, "limit out of range" if @limit < 1 || @limit > MAX_LIMIT

      relation = Note.where(book_id: @book_id)

      if @query
        like = "%#{@query}%"
        relation = relation.where("quote ILIKE :q OR memo ILIKE :q", q: like)
      end

      if @page_from.present?
        relation = relation.where("page >= ?", @page_from.to_i)
      end

      if @page_to.present?
        relation = relation.where("page <= ?", @page_to.to_i)
      end

      relation = relation.order(created_at: :desc)

      total_count = relation.count
      notes       = relation.offset((@page - 1) * @limit).limit(@limit)

      meta = {
        total_count: total_count,
        page:        @page,
        limit:       @limit,
        total_pages: (total_count.to_f / @limit).ceil
      }

      [notes, meta]
    end
  end
end


⸻

2.2 Notes::BulkCreate

（中身はすでに実装済みのやつで OK。ここでは「アウトライン」として位置づけだけ記載。）

# app/services/notes/bulk_create.rb
module Notes
  class BulkCreate
    class BulkInvalid < StandardError
      attr_reader :index, :messages

      def initialize(index:, messages:)
        @index    = index
        @messages = messages
        super("bulk create invalid at index=#{index}")
      end
    end

    MAX_NOTES_PER_REQUEST = 20

    def self.call(book_id:, notes_params:)
      new(book_id:, notes_params:).call
    end

    def initialize(book_id:, notes_params:)
      @book_id      = book_id
      @notes_params = notes_params
    end

    def call
      # 前提チェック
      validate_notes_params!

      book  = Book.alive.find(@book_id)
      notes = []

      ActiveRecord::Base.transaction do
        @notes_params.each_with_index do |raw_attrs, i|
          attrs = raw_attrs.to_h.symbolize_keys.slice(:page, :quote, :memo)
          note  = book.notes.build(attrs)

          unless note.valid?
            raise BulkInvalid.new(index: i, messages: note.errors.full_messages)
          end

          note.save!
          notes << note
        end
      end

      notes
    end

    private

    def validate_notes_params!
      unless @notes_params.is_a?(Array) && @notes_params.any?
        raise ArgumentError, "notes must be a non-empty array"
      end

      if @notes_params.size > MAX_NOTES_PER_REQUEST
        raise ArgumentError, "too many notes (max #{MAX_NOTES_PER_REQUEST})"
      end
    end
  end
end


⸻
