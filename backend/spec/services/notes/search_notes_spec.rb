# spec/services/notes/search_notes_spec.rb
require 'rails_helper'

RSpec.describe Notes::SearchNotes, type: :service do
  describe '.call' do
    let!(:book)  { Book.create!(title: "テスト本", author: "著者") }

    let!(:note1) do
      Note.create!(
        book:  book,
        page:  10,
        quote: "foo",
        memo:  "bar"
      )
    end

    let!(:note2) do
      Note.create!(
        book:  book,
        page:  20,
        quote: "baz",
        memo:  "qux"
      )
    end

    it '何もフィルタしないとき、全件・meta が正しい' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     10
      )

      expect(notes.size).to eq 2
      expect(notes).to all(be_a(Note))

      expect(meta[:total_count]).to eq 2
      expect(meta[:page]).to        eq 1
      expect(meta[:limit]).to       eq 10
      expect(meta[:total_pages]).to eq 1
    end

    it 'query を指定するとその文字列を含むノートだけ返す' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     "foo",
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     10
      )

      expect(notes.size).to eq 1
      expect(notes.first).to eq note1
      expect(meta[:total_count]).to eq 1
    end

    it 'ページネーションが page / limit に従って動く' do
      8.times do |i|
        Note.create!(
          book:  book,
          page:  30 + i,
          quote: "extra #{i}",
          memo:  "m #{i}"
        )
      end

      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      2,
        limit:     5
      )

      expect(meta[:total_count]).to eq 10
      expect(meta[:page]).to        eq 2
      expect(meta[:limit]).to       eq 5
      expect(meta[:total_pages]).to eq 2
      expect(notes.size).to         eq 5
    end

    it '存在しない book_id の場合は ActiveRecord::RecordNotFound を投げる' do
      expect {
        described_class.call(
          book_id:   999_999,
          query:     nil,
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     10
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'page_from / page_to でページ範囲を絞り込む' do
      note_low = Note.create!(book: book, page: 5,  quote: "low",  memo: "m")
      note_mid = Note.create!(book: book, page: 15, quote: "mid",  memo: "m")
      note_hi  = Note.create!(book: book, page: 25, quote: "high", memo: "m")

      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: 10,
        page_to:   20,
        page:      1,
        limit:     50
      )

      pages = notes.map(&:page)

      expect(pages).to contain_exactly(10, 15, 20)
      expect(pages).not_to include(5, 25)
    end

    it 'page_from が page_to より大きい場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book_id:   book.id,
          query:     nil,
          page_from: 20,
          page_to:   10,
          page:      1,
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest, /page_from must be <= page_to/)
    end

    it 'page が整数文字列でない場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book_id:   book.id,
          query:     nil,
          page_from: nil,
          page_to:   nil,
          page:      "abc",
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest, /page が/)
    end

    it 'page_from / page_to が整数文字列でない場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book_id:   book.id,
          query:     nil,
          page_from: "foo",
          page_to:   "20",
          page:      1,
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest, /page_from/)
    end

    it 'page <= 0 の場合は 1 に正規化される' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      0,
        limit:     10
      )

      expect(meta[:page]).to eq 1
    end

    it 'limit が nil のときは DEFAULT_LIMIT になる' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     nil
      )

      expect(meta[:limit]).to eq Notes::SearchNotes::DEFAULT_LIMIT
    end

    it 'memo にだけ含まれるキーワードでも検索にヒットする' do
      note_in_memo = Note.create!(
        book:  book,
        page:  30,
        quote: "AAA",              # quote には "foo" を入れない
        memo:  "this is foo memo"  # memo にだけ "foo"
      )

      note_without_foo = Note.create!(
        book:  book,
        page:  40,
        quote: "BBB",
        memo:  "no match here"
      )

      notes, meta = described_class.call(
        book_id:   book.id,
        query:     "foo",
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     50
      )

      expect(notes).to include(note_in_memo)
      expect(notes).not_to include(note_without_foo)
      # meta の中身まではここでは細かく縛らない（他テストで担保済み）
    end

    it 'limit が MAX_LIMIT を超えた場合、MAX_LIMIT に丸められる' do
      # データは適当に数件あれば十分
      5.times do |i|
        Note.create!(
          book:  book,
          page:  100 + i,
          quote: "q #{i}",
          memo:  "m #{i}"
        )
      end

      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     9999  # MAX_LIMIT を超える大きい値
      )

      expect(meta[:limit]).to eq Notes::SearchNotes::MAX_LIMIT
    end

    it 'soft-deleted book の場合は ActiveRecord::RecordNotFound を投げる' do
      book.update!(deleted_at: Time.current)
    
      expect {
        described_class.call(
          book_id:   book.id,
          query:     nil,
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     10
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    describe '空白区切り AND 検索' do
      it 'q="ラーメン おすすめ" で両方のキーワードを含む note だけ返す' do
        note_both = Note.create!(
          book:  book,
          page:  50,
          quote: "おいしいラーメン",
          memo:  "おすすめの店"
        )
        note_only_ramen = Note.create!(
          book:  book,
          page:  51,
          quote: "ラーメン",
          memo:  "普通"
        )
        note_only_osusume = Note.create!(
          book:  book,
          page:  52,
          quote: "おすすめ",
          memo:  "カレー"
        )

        notes, meta = described_class.call(
          book_id:   book.id,
          query:     "ラーメン おすすめ",
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     50
        )

        expect(notes).to include(note_both)
        expect(notes).not_to include(note_only_ramen, note_only_osusume)
      end

      it 'q="   "（空白のみ）は未指定扱いで全件返す' do
        notes, meta = described_class.call(
          book_id:   book.id,
          query:     "   ",
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     50
        )

        expect(notes.size).to eq Note.where(book_id: book.id).count
      end

      it 'q="ラーメン  おすすめ"（連続空白）でも正しく AND 検索される' do
        note_both = Note.create!(
          book:  book,
          page:  60,
          quote: "おいしいラーメンおすすめ",
          memo:  "test"
        )

        notes, meta = described_class.call(
          book_id:   book.id,
          query:     "ラーメン  おすすめ",  # 連続空白
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     50
        )

        expect(notes).to include(note_both)
      end

      it 'memo=NULL の note でも quote に両トークンが入っていればヒット' do
        note_with_null_memo = Note.create!(
          book:  book,
          page:  70,
          quote: "おいしいラーメンのおすすめ店",
          memo:  nil
        )

        notes, meta = described_class.call(
          book_id:   book.id,
          query:     "ラーメン おすすめ",
          page_from: nil,
          page_to:   nil,
          page:      1,
          limit:     50
        )

        expect(notes).to include(note_with_null_memo)
      end
    end
  end
end