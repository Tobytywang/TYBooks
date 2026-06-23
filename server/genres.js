import { Router } from 'express'
import db from './db.js'
import { authMiddleware } from './middleware/auth.js'

const router = Router()

router.get('/genres', (_req, res) => {
  const genres = db.prepare('SELECT * FROM genres ORDER BY sort_order ASC, id ASC').all()
  res.json(genres)
})

router.get('/genres/:id', (req, res) => {
  const genre = db.prepare('SELECT * FROM genres WHERE id = ?').get(req.params.id)
  if (!genre) return res.status(404).json({ error: 'Not found' })
  res.json(genre)
})

router.post('/genres', authMiddleware, (req, res) => {
  const { name, color, sort_order } = req.body
  if (!name) return res.status(400).json({ error: 'name is required' })
  try {
    const result = db.prepare('INSERT INTO genres (name, color, sort_order) VALUES (?, ?, ?)').run(name, color || 'var(--c-other)', sort_order || 0)
    const genre = db.prepare('SELECT * FROM genres WHERE id = ?').get(result.lastInsertRowid)
    res.json(genre)
  } catch (e: any) {
    if (e.message?.includes('UNIQUE')) return res.status(409).json({ error: '分类名已存在' })
    throw e
  }
})

router.put('/genres/:id', authMiddleware, (req, res) => {
  const existing = db.prepare('SELECT * FROM genres WHERE id = ?').get(req.params.id)
  if (!existing) return res.status(404).json({ error: 'Not found' })
  const { name, color, sort_order } = req.body
  try {
    db.prepare('UPDATE genres SET name=?, color=?, sort_order=? WHERE id=?').run(
      name ?? existing.name,
      color ?? existing.color,
      sort_order ?? existing.sort_order,
      req.params.id
    )
    const genre = db.prepare('SELECT * FROM genres WHERE id = ?').get(req.params.id)
    res.json(genre)
  } catch (e: any) {
    if (e.message?.includes('UNIQUE')) return res.status(409).json({ error: '分类名已存在' })
    throw e
  }
})

router.delete('/genres/:id', authMiddleware, (req, res) => {
  const existing = db.prepare('SELECT * FROM genres WHERE id = ?').get(req.params.id)
  if (!existing) return res.status(404).json({ error: 'Not found' })
  const bookCount = db.prepare('SELECT COUNT(*) as c FROM books WHERE genre = ?').get(existing.name).c
  if (bookCount > 0) return res.status(409).json({ error: `该分类下有 ${bookCount} 本书籍，无法删除` })
  db.prepare('DELETE FROM genres WHERE id = ?').run(req.params.id)
  res.json({ ok: true })
})

export default router
