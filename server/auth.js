import { Router } from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { poolRead } from './db.js'
import { JWT_SECRET } from './middleware/auth.js'

const router = Router()

router.post('/auth/login', async (req, res, next) => {
  try {
    const { username, password } = req.body
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' })
    }

    const { rows } = await poolRead.query('SELECT * FROM users WHERE username = $1', [username])
    if (rows.length === 0) {
      return res.status(401).json({ error: '用户名或密码错误' })
    }

    const user = rows[0]
    const valid = bcrypt.compareSync(password, user.password)
    if (!valid) {
      return res.status(401).json({ error: '用户名或密码错误' })
    }

    const token = jwt.sign(
      { id: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '24h' }
    )

    res.json({ token, username: user.username })
  } catch (e) {
    next(e)
  }
})

router.get('/auth/check', (req, res) => {
  const header = req.headers.authorization
  if (!header || !header.startsWith('Bearer ')) {
    return res.json({ authenticated: false })
  }
  try {
    const token = header.slice(7)
    jwt.verify(token, JWT_SECRET)
    res.json({ authenticated: true })
  } catch {
    res.json({ authenticated: false })
  }
})

export default router
