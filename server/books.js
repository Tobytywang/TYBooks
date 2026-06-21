import { Router } from 'express'
import db from './db.js'

const router = Router()

router.get('/books', (req, res) => {
  const { search, genre, status, sort } = req.query

  let sql = 'SELECT * FROM books WHERE 1=1'
  const params = []

  if (search) {
    sql += ' AND (title LIKE ? OR author LIKE ?)'
    params.push(`%${search}%`, `%${search}%`)
  }
  if (genre) {
    sql += ' AND genre = ?'
    params.push(genre)
  }
  if (status) {
    sql += ' AND status = ?'
    params.push(status)
  }

  const sortMap = {
    title: 'title ASC',
    rating: 'rating DESC, id ASC',
    id: 'id ASC',
  }
  sql += ` ORDER BY ${sortMap[sort] || 'id ASC'}`

  const books = db.prepare(sql).all(...params)
  res.json(books)
})

router.get('/books/:id', (req, res) => {
  const book = db.prepare('SELECT * FROM books WHERE id = ?').get(req.params.id)
  if (!book) return res.status(404).json({ error: 'Not found' })
  res.json(book)
})

router.post('/books', (req, res) => {
  const { emoji, title, author, genre, status, rating, review, tags } = req.body
  if (!title || !author || !genre) {
    return res.status(400).json({ error: 'title, author, genre are required' })
  }
  const result = db.prepare(
    'INSERT INTO books (emoji, title, author, genre, status, rating, review, tags) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(emoji || '📖', title, author, genre, status || 'wish', rating || 0, review || '', tags || '')
  const book = db.prepare('SELECT * FROM books WHERE id = ?').get(result.lastInsertRowid)
  res.json(book)
})

router.put('/books/:id', (req, res) => {
  const existing = db.prepare('SELECT * FROM books WHERE id = ?').get(req.params.id)
  if (!existing) return res.status(404).json({ error: 'Not found' })

  const { emoji, title, author, genre, status, rating, review, tags } = req.body
  db.prepare(
    'UPDATE books SET emoji=?, title=?, author=?, genre=?, status=?, rating=?, review=?, tags=? WHERE id=?'
  ).run(
    emoji ?? existing.emoji,
    title ?? existing.title,
    author ?? existing.author,
    genre ?? existing.genre,
    status ?? existing.status,
    rating ?? existing.rating,
    review ?? existing.review,
    tags ?? existing.tags,
    req.params.id
  )
  const book = db.prepare('SELECT * FROM books WHERE id = ?').get(req.params.id)
  res.json(book)
})

router.delete('/books/:id', (req, res) => {
  const existing = db.prepare('SELECT * FROM books WHERE id = ?').get(req.params.id)
  if (!existing) return res.status(404).json({ error: 'Not found' })
  db.prepare('DELETE FROM books WHERE id = ?').run(req.params.id)
  res.json({ ok: true })
})

router.get('/stats', (_req, res) => {
  const total = db.prepare('SELECT COUNT(*) as c FROM books').get().c
  const done = db.prepare("SELECT COUNT(*) as c FROM books WHERE status = 'done'").get().c
  const reading = db.prepare("SELECT COUNT(*) as c FROM books WHERE status = 'reading'").get().c
  const wish = db.prepare("SELECT COUNT(*) as c FROM books WHERE status = 'wish'").get().c
  const tobuy = db.prepare("SELECT COUNT(*) as c FROM books WHERE status = 'tobuy'").get().c
  const reread = db.prepare("SELECT COUNT(*) as c FROM books WHERE status = 'reread'").get().c
  const byGenre = db.prepare('SELECT genre, COUNT(*) as count FROM books GROUP BY genre ORDER BY count DESC').all()
  res.json({ total, done, reading, wish, tobuy, reread, byGenre })
})

export default router
