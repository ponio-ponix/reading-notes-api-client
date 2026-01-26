# app/services/notes/bulk_create.rb

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
        raise ArgumentError, "notes must be a non-empty array"
      end
      if notes_params.size > MAX_NOTES_PER_REQUEST
        raise ArgumentError, "too many notes (max #{MAX_NOTES_PER_REQUEST})"
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