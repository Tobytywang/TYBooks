import 'dotenv/config'
import express from 'express'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import booksRouter from './books.js'
import authRouter from './auth.js'
import genresRouter from './genres.js'
import statusRouter from './status.js'
import { initDB } from './db.js'
import { wrapPool } from './middleware/queryLog.js'
import './middleware/serverLog.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

app.use(express.json())
app.use('/api', authRouter)
app.use('/api', genresRouter)
app.use('/api', booksRouter)
app.use('/api', statusRouter)

app.use(express.static(join(__dirname, '..', 'dist')))
app.get('*', (_req, res) => {
  res.sendFile(join(__dirname, '..', 'dist', 'index.html'))
})

async function start() {
  const maxRetries = 10
  for (let i = 1; i <= maxRetries; i++) {
    try {
      await initDB()
      app.listen(PORT, () => {
        console.log(`Server running at http://localhost:${PORT}`)
      })
      return
    } catch (e) {
      console.error(`\n${'='.repeat(50)}`)
      console.error(`  数据库连接失败 (${i}/${maxRetries})`)
      console.error(`  错误: ${e.message}`)
      console.error(`  DATABASE_URL: ${process.env.DATABASE_URL || '(未设置)'}`)
      console.error(`${'='.repeat(50)}\n`)
      if (i < maxRetries) {
        console.log(`  ${3} 秒后重试...\n`)
        await new Promise(r => setTimeout(r, 3000))
      }
    }
  }
  console.error(`\n${'!'.repeat(50)}`)
  console.error(`  数据库连接失败，已重试 ${maxRetries} 次`)
  console.error(`  请检查 DATABASE_URL 配置和数据库状态`)
  console.error(`${'!'.repeat(50)}\n`)
  process.exit(1)
}

start()
