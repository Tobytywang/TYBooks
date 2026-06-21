import { ref, computed } from 'vue'
import { login as apiLogin, checkAuth } from '../api/auth'

const token = ref(localStorage.getItem('token') || '')
const username = ref(localStorage.getItem('username') || '')
const isAuthenticated = computed(() => !!token.value)

async function login(user: string, pass: string) {
  const data = await apiLogin(user, pass)
  token.value = data.token
  username.value = data.username
  localStorage.setItem('token', data.token)
  localStorage.setItem('username', data.username)
}

function logout() {
  token.value = ''
  username.value = ''
  localStorage.removeItem('token')
  localStorage.removeItem('username')
}

async function verify() {
  const valid = await checkAuth()
  if (!valid) {
    logout()
  }
  return valid
}

function authHeaders(): Record<string, string> {
  if (!token.value) return {}
  return { Authorization: `Bearer ${token.value}` }
}

export function useAuth() {
  return {
    token,
    username,
    isAuthenticated,
    login,
    logout,
    verify,
    authHeaders,
  }
}
