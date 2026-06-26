import { Router } from 'express'
import { pool, poolRead } from './db.js'
import { authMiddleware } from './middleware/auth.js'

const router = Router()

router.get('/genres', async (_req, res, next) => {
  try {
    const { rows } = await poolRead.query('SELECT * FROM genres ORDER BY sort_order ASC, id ASC')
    res.json(rows)
  } catch (e) {
    next(e)
  }
})

router.get('/genres/:id', async (req, res, next) => {
  try {
    const { rows } = await poolRead.query('SELECT * FROM genres WHERE id = $1', [req.params.id])
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' })
    res.json(rows[0])
  } catch (e) {
    next(e)
  }
})

router.post('/genres', authMiddleware, async (req, res, next) => {
  const { name, color, sort_order } = req.body
  if (!name) return res.status(400).json({ error: 'name is required' })
  try {
    const { rows } = await pool.query(
      'INSERT INTO genres (name, color, sort_order) VALUES ($1, $2, $3) RETURNING *',
      [name, color || 'var(--c-other)', sort_order || 0]
    )
    res.json(rows[0])
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: '分类名已存在' })
    next(e)
  }
})

router.put('/genres/:id', authMiddleware, async (req, res, next) => {
  try {
    const { rows: existing } = await poolRead.query('SELECT * FROM genres WHERE id = $1', [req.params.id])
    if (existing.length === 0) return res.status(404).json({ error: 'Not found' })
    const { name, color, sort_order } = req.body
    const { rows } = await pool.query(
      'UPDATE genres SET name=$1, color=$2, sort_order=$3 WHERE id=$4 RETURNING *',
      [
        name ?? existing[0].name,
        color ?? existing[0].color,
        sort_order ?? existing[0].sort_order,
        req.params.id,
      ]
    )
    res.json(rows[0])
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: '分类名已存在' })
    next(e)
  }
})

router.delete('/genres/:id', authMiddleware, async (req, res, next) => {
  try {
    const { rows: existing } = await poolRead.query('SELECT * FROM genres WHERE id = $1', [req.params.id])
    if (existing.length === 0) return res.status(404).json({ error: 'Not found' })
    const { rows: [{ c: bookCount }] } = await poolRead.query('SELECT COUNT(*) as c FROM books WHERE genre = $1', [existing[0].name])
    if (Number(bookCount) > 0) return res.status(409).json({ error: `该分类下有 ${bookCount} 本书籍，无法删除` })
    await pool.query('DELETE FROM genres WHERE id = $1', [req.params.id])
    res.json({ ok: true })
  } catch (e) {
    next(e)
  }
})

export default router
