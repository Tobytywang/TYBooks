import type { Genre } from '../types/book'
import { useAuth } from '../composables/useAuth'

const BASE = '/api'

export async function fetchGenres(): Promise<Genre[]> {
  const res = await fetch(`${BASE}/genres`)
  return res.json()
}

export async function fetchGenre(id: number): Promise<Genre> {
  const res = await fetch(`${BASE}/genres/${id}`)
  return res.json()
}

export async function createGenre(data: { name: string; color?: string; sort_order?: number }): Promise<Genre> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/genres`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(data),
  })
  if (res.status === 409) throw new Error('分类名已存在')
  if (res.status === 401) throw new Error('未登录或登录已过期')
  return res.json()
}

export async function updateGenre(id: number, data: Partial<{ name: string; color: string; sort_order: number }>): Promise<Genre> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/genres/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(data),
  })
  if (res.status === 409) throw new Error('分类名已存在')
  if (res.status === 401) throw new Error('未登录或登录已过期')
  return res.json()
}

export async function deleteGenre(id: number): Promise<void> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/genres/${id}`, {
    method: 'DELETE',
    headers: authHeaders(),
  })
  if (res.status === 409) {
    const data = await res.json()
    throw new Error(data.error)
  }
  if (res.status === 401) throw new Error('未登录或登录已过期')
}
