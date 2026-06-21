const BASE = '/api'

export async function login(username: string, password: string): Promise<{ token: string; username: string }> {
  const res = await fetch(`${BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  })
  if (!res.ok) {
    const data = await res.json()
    throw new Error(data.error || '登录失败')
  }
  return res.json()
}

export async function checkAuth(): Promise<boolean> {
  const token = localStorage.getItem('token')
  if (!token) return false
  const res = await fetch(`${BASE}/auth/check`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  const data = await res.json()
  return data.authenticated
}
