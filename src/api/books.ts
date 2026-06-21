import type { Book, BookCreate, Stats, StatusFilter, SortKey } from '../types/book'
import { useAuth } from '../composables/useAuth'

const BASE = '/api'

export async function fetchBooks(params?: {
  search?: string
  genre?: string
  status?: StatusFilter
  sort?: SortKey
}): Promise<Book[]> {
  const sp = new URLSearchParams()
  if (params?.search) sp.set('search', params.search)
  if (params?.genre) sp.set('genre', params.genre)
  if (params?.status) sp.set('status', params.status)
  if (params?.sort) sp.set('sort', params.sort)
  const qs = sp.toString()
  const res = await fetch(`${BASE}/books${qs ? '?' + qs : ''}`)
  return res.json()
}

export async function fetchBook(id: number): Promise<Book> {
  const res = await fetch(`${BASE}/books/${id}`)
  return res.json()
}

export async function createBook(data: BookCreate): Promise<Book> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/books`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(data),
  })
  if (res.status === 401) throw new Error('未登录或登录已过期')
  return res.json()
}

export async function updateBook(id: number, data: Partial<BookCreate>): Promise<Book> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/books/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(data),
  })
  if (res.status === 401) throw new Error('未登录或登录已过期')
  return res.json()
}

export async function deleteBook(id: number): Promise<void> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/books/${id}`, {
    method: 'DELETE',
    headers: authHeaders(),
  })
  if (res.status === 401) throw new Error('未登录或登录已过期')
}

export async function fetchStats(): Promise<Stats> {
  const res = await fetch(`${BASE}/stats`)
  return res.json()
}
