import express from 'express'
import cors from 'cors'
import booksRouter from './books.js'
import authRouter from './auth.js'

const app = express()
const PORT = 3001

app.use(cors())
app.use(express.json())
app.use('/api', authRouter)
app.use('/api', booksRouter)

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`)
})
