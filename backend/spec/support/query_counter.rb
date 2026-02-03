# spec/support/query_counter.rb
module QueryCounter
  SQL_EVENT = "sql.active_record".freeze

  IGNORE_NAME = /\A(?:SCHEMA|TRANSACTION|CACHE)\z/.freeze

  def self.count_book_selects(&block)
    count_selects_for_table("books", &block)
  end

  def self.count_selects_for_table(table, &block)
    count = 0

    callback = lambda do |_name, _start, _finish, _id, payload|
      # payload[:name] は "Book Load" とか "CACHE" とか
      name = payload[:name].to_s
      return if name.match?(IGNORE_NAME)

      sql = payload[:sql].to_s
      return unless sql.lstrip.start_with?("SELECT")

      # FROM "books" / FROM books を拾う（DB差を吸収）
      from_books = sql.match?(/FROM\s+"?#{Regexp.escape(table)}"?\b/i)
      return unless from_books

      count += 1
    end

    ActiveSupport::Notifications.subscribed(callback, SQL_EVENT) do
      yield
    end

    count
  end
end