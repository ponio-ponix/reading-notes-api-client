import { useEffect, useState, FormEvent } from "react"

type Book = {
  id: number
  title: string
  author: string | null
}

type Note = {
  id: number
  book_id: number
  page: number | null
  quote: string
  memo: string | null
  created_at: string
}

type NotesMeta = {
  total_count: number
  page: number
  limit: number
  total_pages: number
}

type NotesIndexResponse = {
  notes: Note[]
  meta: NotesMeta
}

function App() {
  const [books, setBooks] = useState<Book[]>([])
  const [selectedBookId, setSelectedBookId] = useState<number | null>(null)
  const [notes, setNotes] = useState<Note[]>([])

  // フォーム用
  const [notePage, setNotePage] = useState<string>("")
  const [quote, setQuote] = useState<string>("")
  const [memo, setMemo] = useState<string>("")

  const [error, setError] = useState<string | null>(null)
  const [loadingNotes, setLoadingNotes] = useState(false)

  const [newTitle, setNewTitle] = useState("")
  const [newAuthor, setNewAuthor] = useState("")

  // 検索 & ページネーション
  const [searchQuery, setSearchQuery] = useState("")
  const [currentPage, setCurrentPage] = useState(1)
  const [notesMeta, setNotesMeta] = useState<NotesMeta | null>(null)
  const PER_PAGE = 10

  // 本一覧を取得
  useEffect(() => {
    fetch("/api/books")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.json()
      })
      .then((data: Book[]) => {
        setBooks(data)
        if (data.length > 0 && selectedBookId === null) {
          setSelectedBookId(data[0].id)
        }
      })
      .catch((err) => {
        console.error(err)
        setError(err.message)
      })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // 本が変わったらページ番号をリセット
  useEffect(() => {
    setCurrentPage(1)
  }, [selectedBookId])

  // ノート取得（検索＋ページネーション）
  useEffect(() => {
    if (selectedBookId == null) return

    setLoadingNotes(true)
    setError(null)

    const params = new URLSearchParams()
    if (searchQuery.trim() !== "") {
      params.append("q", searchQuery.trim())
    }
    params.append("page", String(currentPage))
    params.append("limit", String(PER_PAGE))

    fetch(`/api/books/${selectedBookId}/notes?${params.toString()}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.json()
      })
      .then((data: NotesIndexResponse) => {
        setNotes(data.notes)
        setNotesMeta(data.meta)
      })
      .catch((err) => {
        console.error(err)
        setError(err.message)
      })
      .finally(() => {
        setLoadingNotes(false)
      })
  }, [selectedBookId, searchQuery, currentPage])

  const handleAddBook = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!newTitle.trim()) {
      setError("タイトルは必須です")
      return
    }

    try {
      const res = await fetch("/api/books", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          book: {
            title: newTitle,
            author: newAuthor,
          },
        }),
      })

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`)
      }

      const created: Book = await res.json()

      setBooks((prev) => [created, ...prev])
      setSelectedBookId(created.id)
      setNewTitle("")
      setNewAuthor("")
    } catch (err: any) {
      console.error("Failed to create book", err)
      setError(err.message ?? "Failed to create book")
    }
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    if (selectedBookId == null) return
    if (!quote.trim()) {
      alert("引用は必須です")
      return
    }

    const payload = {
      note: {
        page: notePage ? Number(notePage) : null,
        quote: quote.trim(),
        memo: memo.trim() || null,
      },
    }

    fetch(`/api/books/${selectedBookId}/notes`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.json()
      })
      .then((created: Note) => {
        // ローカルの一覧先頭に追加
        setNotes((prev) => [created, ...prev])

        if (notePage) {
          const next = Number(notePage) + 1
          setNotePage(String(next))
        }
        setQuote("")
        setMemo("")
      })
      .catch((err) => {
        console.error(err)
        setError(err.message)
      })
  }

  const currentBook = books.find((b) => b.id === selectedBookId) || null

  return (
    <div style={{ padding: "16px", maxWidth: 800, margin: "0 auto" }}>
      <h1>読書引用インボックス（MVP）</h1>

      {/* 本一覧 */}
      <section style={{ marginBottom: 24 }}>
        <h2>本一覧</h2>
        {books.length === 0 && <p>まだ本がありません。</p>}
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
          {books.map((book) => (
            <button
              key={book.id}
              type="button"
              onClick={() => setSelectedBookId(book.id)}
              style={{
                padding: "4px 8px",
                borderRadius: 4,
                border:
                  selectedBookId === book.id
                    ? "2px solid #007acc"
                    : "1px solid #ccc",
                backgroundColor:
                  selectedBookId === book.id ? "#e6f3ff" : "#ffffff",
                color: "#222",
                cursor: "pointer",
              }}
            >
              {book.title}
            </button>
          ))}
        </div>
      </section>

      <hr />

      {/* 対象の本 */}
      <section style={{ marginTop: 16, marginBottom: 24 }}>
        <h2>対象の本</h2>
        {currentBook ? (
          <p>
            {currentBook.title} / {currentBook.author ?? "著者不明"}
          </p>
        ) : (
          <p>本が選択されていません。</p>
        )}
      </section>

      {/* 引用フォーム */}
      {currentBook && (
        <section style={{ marginBottom: 32 }}>
          <h2>引用を追加</h2>
          <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: 8 }}>
              <label>
                ページ:
                <input
                  type="number"
                  value={notePage}
                  onChange={(e) => setNotePage(e.target.value)}
                  style={{ marginLeft: 8, width: 80 }}
                  min={1}
                />
              </label>
            </div>

            <div style={{ marginBottom: 8 }}>
              <label>
                引用（必須）:
                <br />
                <textarea
                  value={quote}
                  onChange={(e) => setQuote(e.target.value)}
                  rows={3}
                  style={{ width: "100%" }}
                  required
                />
              </label>
            </div>

            <div style={{ marginBottom: 8 }}>
              <label>
                メモ（任意）:
                <br />
                <textarea
                  value={memo}
                  onChange={(e) => setMemo(e.target.value)}
                  rows={2}
                  style={{ width: "100%" }}
                />
              </label>
            </div>

            <button type="submit">保存する</button>
          </form>
        </section>
      )}

      {/* エラー表示 */}
      {error && <p style={{ color: "red" }}>Error: {error}</p>}

      {/* ノート一覧 ＋ 検索 ＋ ページネーション */}
      <section>
        <h2>保存済みの引用</h2>

        {/* 検索フォーム */}
        <div style={{ marginBottom: 8 }}>
          <input
            type="text"
            placeholder="キーワード検索（quote / memo）"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value)
              setCurrentPage(1)
            }}
            style={{ width: "100%", padding: 4 }}
          />
        </div>

        {loadingNotes && <p>読み込み中…</p>}
        {!loadingNotes && notes.length === 0 && (
          <p>まだこの本の引用はありません。</p>
        )}

        {notes.map((note) => (
          <div
            key={note.id}
            style={{
              border: "1px solid #ddd",
              padding: 8,
              marginBottom: 8,
              borderRadius: 4,
            }}
          >
            <div style={{ fontSize: 12, color: "#555" }}>
              p.{note.page ?? "-"}{" "}
              {new Date(note.created_at).toLocaleString("ja-JP")}
            </div>
            <div style={{ marginTop: 4 }}>{note.quote}</div>
            {note.memo && (
              <div style={{ marginTop: 4, fontSize: 12, color: "#333" }}>
                メモ: {note.memo}
              </div>
            )}
          </div>
        ))}

        {/* ページネーション */}
        {notesMeta && notesMeta.total_pages > 1 && (
          <div
            style={{
              marginTop: 12,
              display: "flex",
              alignItems: "center",
              gap: 8,
            }}
          >
            <button
              type="button"
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={currentPage <= 1}
            >
              前へ
            </button>
            <span>
              {currentPage} / {notesMeta.total_pages}
            </span>
            <button
              type="button"
              onClick={() =>
                setCurrentPage((p) =>
                  Math.min(notesMeta.total_pages, p + 1),
                )
              }
              disabled={currentPage >= notesMeta.total_pages}
            >
              次へ
            </button>
          </div>
        )}
      </section>
    </div>
  )
}

export default App