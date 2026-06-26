import { Router } from 'express'
import { pool, poolRead } from './db.js'
import { authMiddleware } from './middleware/auth.js'

const router = Router()

router.get('/books', async (req, res, next) => {
  try {
    const { search, genre, status, sort, page, pageSize } = req.query

    let sql = 'SELECT * FROM books WHERE 1=1'
    const params = []
    let idx = 1

    if (search) {
      sql += ` AND (title LIKE $${idx} OR author LIKE $${idx + 1})`
      params.push(`%${search}%`, `%${search}%`)
      idx += 2
    }
    if (genre) {
      sql += ` AND genre = $${idx}`
      params.push(genre)
      idx++
    }
    if (status) {
      sql += ` AND status = $${idx}`
      params.push(status)
      idx++
    }

    const sortMap = {
      title: 'title ASC',
      rating: 'rating DESC, id ASC',
      id: 'id ASC',
    }
    sql += ` ORDER BY ${sortMap[sort] || 'id ASC'}`

    if (page !== undefined) {
      const p = Math.max(1, Number(page) || 1)
      const ps = Math.max(1, Number(pageSize) || 20)
      const countSql = sql.split(' ORDER BY ')[0].replace('SELECT *', 'SELECT COUNT(*) as total')
      const { rows: [{ total }] } = await poolRead.query(countSql, params)
      const offset = (p - 1) * ps
      sql += ` LIMIT $${idx} OFFSET $${idx + 1}`
      const { rows: data } = await poolRead.query(sql, [...params, ps, offset])
      return res.json({ data, total: Number(total), page: p, pageSize: ps })
    }

    const { rows } = await poolRead.query(sql, params)
    res.json(rows)
  } catch (e) {
    next(e)
  }
})

router.get('/books/:id', async (req, res, next) => {
  try {
    const { rows } = await poolRead.query('SELECT * FROM books WHERE id = $1', [req.params.id])
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' })
    res.json(rows[0])
  } catch (e) {
    next(e)
  }
})

router.post('/books', authMiddleware, async (req, res, next) => {
  try {
    const { emoji, title, author, genre, status, rating, review, tags } = req.body
    if (!title || !author || !genre) {
      return res.status(400).json({ error: 'title, author, genre are required' })
    }
    const { rows } = await pool.query(
      'INSERT INTO books (emoji, title, author, genre, status, rating, review, tags) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *',
      [emoji || '📖', title, author, genre, status || 'wish', rating || 0, review || '', tags || '']
    )
    res.json(rows[0])
  } catch (e) {
    next(e)
  }
})

router.put('/books/:id', authMiddleware, async (req, res, next) => {
  try {
    const { rows: existing } = await poolRead.query('SELECT * FROM books WHERE id = $1', [req.params.id])
    if (existing.length === 0) return res.status(404).json({ error: 'Not found' })

    const { emoji, title, author, genre, status, rating, review, tags } = req.body
    const { rows } = await pool.query(
      'UPDATE books SET emoji=$1, title=$2, author=$3, genre=$4, status=$5, rating=$6, review=$7, tags=$8 WHERE id=$9 RETURNING *',
      [
        emoji ?? existing[0].emoji,
        title ?? existing[0].title,
        author ?? existing[0].author,
        genre ?? existing[0].genre,
        status ?? existing[0].status,
        rating ?? existing[0].rating,
        review ?? existing[0].review,
        tags ?? existing[0].tags,
        req.params.id,
      ]
    )
    res.json(rows[0])
  } catch (e) {
    next(e)
  }
})

router.delete('/books/:id', authMiddleware, async (req, res, next) => {
  try {
    const { rows: existing } = await poolRead.query('SELECT * FROM books WHERE id = $1', [req.params.id])
    if (existing.length === 0) return res.status(404).json({ error: 'Not found' })
    await pool.query('DELETE FROM books WHERE id = $1', [req.params.id])
    res.json({ ok: true })
  } catch (e) {
    next(e)
  }
})

router.get('/stats', async (_req, res, next) => {
  try {
    const q = async (sql, params) => {
      const { rows } = await poolRead.query(sql, params)
      return Number(rows[0].c)
    }
    const total = await q('SELECT COUNT(*) as c FROM books')
    const done = await q("SELECT COUNT(*) as c FROM books WHERE status = 'done'")
    const reading = await q("SELECT COUNT(*) as c FROM books WHERE status = 'reading'")
    const wish = await q("SELECT COUNT(*) as c FROM books WHERE status = 'wish'")
    const tobuy = await q("SELECT COUNT(*) as c FROM books WHERE status = 'tobuy'")
    const reread = await q("SELECT COUNT(*) as c FROM books WHERE status = 'reread'")
    const { rows: byGenre } = await poolRead.query('SELECT genre, COUNT(*) as count FROM books GROUP BY genre ORDER BY count DESC')
    res.json({
      total, done, reading, wish, tobuy, reread,
      byGenre: byGenre.map(g => ({ genre: g.genre, count: Number(g.count) })),
    })
  } catch (e) {
    next(e)
  }
})

export default router
