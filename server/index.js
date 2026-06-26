import 'dotenv/config'
import express from 'express'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import booksRouter from './books.js'
import authRouter from './auth.js'
import genresRouter from './genres.js'
import { initDB } from './db.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const app = express()
const PORT = process.env.PORT || 8080

app.use(express.json())
app.use('/api', authRouter)
app.use('/api', genresRouter)
app.use('/api', booksRouter)

app.use(express.static(join(__dirname, '..', 'dist')))
app.get('*', (_req, res) => {
  res.sendFile(join(__dirname, '..', 'dist', 'index.html'))
})

initDB().then(() => {
  app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`)
  })
})
