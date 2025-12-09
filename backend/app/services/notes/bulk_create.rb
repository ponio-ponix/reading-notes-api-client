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
      # 1. notes_params の前提チェック（API Contract の Constraints を反映）
      unless notes_params.is_a?(Array) && notes_params.any?
        # ここは 400 にマッピングする想定（ApplicationController で rescue）
        raise ArgumentError, "notes must be a non-empty array"
      end

      if notes_params.size > MAX_NOTES_PER_REQUEST
        raise ArgumentError, "too many notes (max #{MAX_NOTES_PER_REQUEST})"
      end

      book  = Book.find(book_id)
      notes = []

      ActiveRecord::Base.transaction do
        notes_params.each_with_index do |raw_attrs, i|
          # 2. key 正規化（string/symbol 混在対策）
          attrs = raw_attrs.to_h.symbolize_keys.slice(:page, :quote, :memo)

          note = book.notes.build(attrs)

          unless note.valid?
            # この時点で「どの index で失敗したか」を握って例外
            raise BulkInvalid.new(index: i, messages: note.errors.full_messages)
          end

          # ここは基本的に通るはずだが、DB制約違反などがあれば例外
          note.save!
          notes << note
        end
      end

      notes
    end
  end
end