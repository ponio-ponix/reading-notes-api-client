# spec/services/notes/search_notes_spec.rb
require 'rails_helper'

RSpec.describe Notes::SearchNotes, type: :service do
  describe '.call' do
    let!(:user) do
      User.create!(
        email: "search-spec-#{SecureRandom.hex(4)}@example.com",
        password: "password"
      )
    end
    
    let!(:book) { Book.create!(user: user, title: "テスト本", author: "著者") }

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

    let!(:note3) do
      Note.create!(
        book:  book,
        page:  10,
        quote: "eee",
        memo:  "ddd"
      )
    end

    it '空白の query は未指定扱い（nil）と同じ結果を返す' do
      Note.create!(book: book, page: 1, quote: "a", memo: "b")
      Note.create!(book: book, page: 2, quote: "c", memo: nil)
    
      notes_blank, meta_blank = described_class.call(
        book: book, query: "   ", page_from: nil, page_to: nil, page: 1, limit: 50
      )
    
      notes_nil, meta_nil = described_class.call(
        book: book, query: nil, page_from: nil, page_to: nil, page: 1, limit: 50
      )
    
      expect(notes_blank).to match_array(notes_nil)
      expect(meta_blank[:total_count]).to eq meta_nil[:total_count]
    end

    it '何もフィルタしないとき、全件・meta が正しい' do
      notes, meta = described_class.call(
        book:   book,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     10
      )

      expect(notes.size).to eq 3
      expect(notes).to all(be_a(Note))

      expect(meta[:total_count]).to eq 3
      expect(meta[:page]).to        eq 1
      expect(meta[:limit]).to       eq 10
      expect(meta[:total_pages]).to eq 1
    end

    it 'query を指定するとその文字列を含むノートだけ返す' do
      notes, meta = described_class.call(
        book:   book,
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
        book:   book,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      2,
        limit:     5
      )

      expect(meta[:total_count]).to eq 11
      expect(meta[:page]).to        eq 2
      expect(meta[:limit]).to       eq 5
      expect(meta[:total_pages]).to eq 3
      expect(notes.size).to         eq 5
    end

    describe '検索結果の並び順とページネーションの安定性' do
      fixed_time = Time.zone.parse("2026-10-14 12:00:00")
      let!(:note4) { Note.create!(book: book, page: 10, quote: "44foo", memo: "44bar", created_at: fixed_time) }
      let!(:note5) { Note.create!(book: book, page: 11, quote: "55foo", memo: "55bar", created_at: fixed_time) }
      let!(:note6) { Note.create!(book: book, page: 12, quote: "66foo", memo: "66bar", created_at: fixed_time) }

      let!(:note7_standard) { Note.create!(book: book, page: 10, quote: "77foo", memo: "77bar", created_at: Time.zone.parse("2026-10-14 12:00:02")) }
      let!(:note8_minusone) { Note.create!(book: book, page: 11, quote: "88foo", memo: "88bar", created_at: Time.zone.parse("2026-10-14 12:00:01")) }
      let!(:note9_minustwo) { Note.create!(book: book, page: 12, quote: "99foo", memo: "99bar", created_at: Time.zone.parse("2026-10-14 12:00:00")) }


      it '1ページ目と2ページ目で同じNote IDが返されない' do

        notes1, meta1 = described_class.call(
          book:      book,
          query:     nil,
          page_from: 10,
          page_to:   20,
          page:      1,
          limit:     4
        )

        notes2, meta2 = described_class.call(
          book:      book,
          query:     nil,
          page_from: 10,
          page_to:   20,
          page:      2,
          limit:     4
        )

        ids1 = notes1.map(&:id)
        ids2 = notes2.map(&:id)

        expect(ids1 & ids2).to be_empty

      end

      it 'created_atが同じNotesはIDの昇順で返される' do

        notes, meta = described_class.call(
          book:      book,
          query:     nil,
          page_from: 10,
          page_to:   20,
          page:      1,
          limit:     50
        )
        test_note4 = notes.find { |note| note.id == note4.id }
        test_note5 = notes.find { |note| note.id == note5.id }
        test_note6 = notes.find { |note| note.id == note6.id }

        expect(test_note4.created_at).to eq(test_note5.created_at)
        expect(test_note5.created_at).to eq(test_note6.created_at)

        notes_array = notes.to_a

        index4 = notes_array.index(note4)
        index5 = notes_array.index(note5)
        index6 = notes_array.index(note6)

        expect(index4).to be < index5
        expect(index5).to be < index6

      end

      it 'created_atが異なるNotesは新しい日時の順に返される' do
        notes, meta = described_class.call(
          book:      book,
          query:     nil,
          page_from: 10,
          page_to:   20,
          page:      1,
          limit:     50
        )

        test_note7 = notes.find { |note| note.id == note7_standard.id }
        test_note8 = notes.find { |note| note.id == note8_minusone.id }
        test_note9 = notes.find { |note| note.id == note9_minustwo.id }

        expect(test_note8.created_at).to be < test_note7.created_at
        expect(test_note9.created_at).to be < test_note8.created_at

        notes_array = notes.to_a

        index7 = notes_array.index(note7_standard)
        index8 = notes_array.index(note8_minusone)
        index9 = notes_array.index(note9_minustwo)

        expect(index9).to be > index8
        expect(index8).to be > index7

      end
    end

    it 'page_from / page_to でページ範囲を絞り込む' do
      note_low = Note.create!(book: book, page: 5,  quote: "low",  memo: "m")
      note_mid = Note.create!(book: book, page: 15, quote: "mid",  memo: "m")
      note_hi  = Note.create!(book: book, page: 25, quote: "high", memo: "m")

      notes, meta = described_class.call(
        book:   book,
        query:     nil,
        page_from: 10,
        page_to:   20,
        page:      1,
        limit:     50
      )

      pages = notes.map(&:page)

      expect(pages).to contain_exactly(10, 10, 15, 20)
      expect(pages).not_to include(5, 25)
    end

    it 'page_from が page_to より大きい場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book:   book,
          query:     nil,
          page_from: 20,
          page_to:   10,
          page:      1,
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest)
    end

    it 'page が整数文字列でない場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book:   book,
          query:     nil,
          page_from: nil,
          page_to:   nil,
          page:      "abc",
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest)
    end

    it 'page_from / page_to が整数文字列でない場合は BadRequest を投げる' do
      expect {
        described_class.call(
          book:   book,
          query:     nil,
          page_from: "foo",
          page_to:   "20",
          page:      1,
          limit:     10
        )
      }.to raise_error(ApplicationErrors::BadRequest)
    end

    it 'page <= 0 の場合は 1 に正規化される' do
      notes, meta = described_class.call(
        book:   book,
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
        book:   book,
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
        book:   book,
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
        book:   book,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     9999  # MAX_LIMIT を超える大きい値
      )

      expect(meta[:limit]).to eq Notes::SearchNotes::MAX_LIMIT
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
          book:  book,
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
          book:   book,
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
          book:   book,
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
          book:   book,
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