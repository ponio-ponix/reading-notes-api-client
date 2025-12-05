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

function App() {
  const [books, setBooks] = useState<Book[]>([])
  const [selectedBookId, setSelectedBookId] = useState<number | null>(null)
  const [notes, setNotes] = useState<Note[]>([])

  const [page, setPage] = useState<string>("")
  const [quote, setQuote] = useState<string>("")
  const [memo, setMemo] = useState<string>("")

  const [error, setError] = useState<string | null>(null)
  const [loadingNotes, setLoadingNotes] = useState(false)

  const [newTitle, setNewTitle] = useState("")
  const [newAuthor, setNewAuthor] = useState("")

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
  }, [])

  // 選択中の本のノートを取得
  useEffect(() => {
    if (selectedBookId == null) return

    setLoadingNotes(true)
    setError(null)

    fetch(`/api/books/${selectedBookId}/notes`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.json()
      })
      .then((data: Note[]) => {
        setNotes(data)
      })
      .catch((err) => {
        console.error(err)
        setError(err.message)
      })
      .finally(() => {
        setLoadingNotes(false)
      })
  }, [selectedBookId])

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

      // 本一覧に追加
      setBooks((prev) => [created, ...prev])
      // 追加した本を選択状態にする
      setSelectedBookId(created.id)
      // フォームクリア
      setNewTitle("")
      setNewAuthor("")
    } catch (err: any) {
      console.error("Failed to create book", err)
      setError(err.message ?? "Failed to create book")
    }
  }

  const handleSaveNote = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)

    if (selectedBookId == null) {
      setError("本が選択されていません")
      return
    }
    if (!quote.trim()) {
      setError("引用は必須です")
      return
    }

    // page の変換（空文字なら null）
    const pageValue =
      page.trim() === "" ? null : Number.isNaN(Number(page)) ? null : Number(page)

    try {
      const res = await fetch(`/api/books/${selectedBookId}/notes`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          note: {
            page: pageValue,
            quote,
            memo,
          },
        }),
      })

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`)
      }

      const created: Note = await res.json()

      // 先頭に追加
      setNotes((prev) => [created, ...prev])

      // ページだけ +1（数値が入っていた場合）
      if (pageValue != null) {
        setPage(String(pageValue + 1))
      } else {
        setPage("")
      }
      setQuote("")
      setMemo("")
    } catch (err: any) {
      console.error("Failed to create note", err)
      setError(err.message ?? "Failed to create note")
    }
  }

  const currentBook = books.find((b) => b.id === selectedBookId) || null

  // 引用保存
  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    if (selectedBookId == null) return
    if (!quote.trim()) {
      alert("引用は必須です")
      return
    }

    const payload = {
      note: {
        page: page ? Number(page) : null,
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
        // 先頭に追加
        setNotes((prev) => [created, ...prev])

        // フォームリセット：ページだけ +1
        if (page) {
          const next = Number(page) + 1
          setPage(String(next))
        }
        setQuote("")
        setMemo("")
      })
      .catch((err) => {
        console.error(err)
        setError(err.message)
      })
  }

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
              color: "#222",              // ← これを追加
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
                  value={page}
                  onChange={(e) => setPage(e.target.value)}
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

      {/* ノート一覧 */}
      <section>
        <h2>保存済みの引用</h2>
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
      </section>
    </div>
  )
}

export default App