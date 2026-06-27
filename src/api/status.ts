import { useAuth } from '../composables/useAuth'

const BASE = '/api'

export interface QueryLogItem {
  id: number
  time: string
  sql: string
  duration: number
}

export interface ServerLogItem {
  time: string
  level: string
  message: string
}

export interface SystemStatus {
  backend: BackendStatus
  database: DatabaseStatus
  queryLog: QueryLogItem[]
  serverLog: ServerLogItem[]
}

export interface BackendStatus {
  status: string
  uptime: number
  nodeVersion: string
  port: number | string
}

export interface DatabaseStatus {
  status: string
  latency?: number
  pgVersion?: string
  poolTotal?: number
  poolIdle?: number
  poolWaiting?: number
  error?: string
}

export interface SystemStatus {
  backend: BackendStatus
  database: DatabaseStatus
  queryLog: QueryLogItem[]
}

export async function fetchStatus(): Promise<SystemStatus> {
  const { authHeaders } = useAuth()
  const res = await fetch(`${BASE}/status`, {
    headers: authHeaders(),
  })
  if (res.status === 401) throw new Error('未登录或登录已过期')
  if (!res.ok) throw new Error('获取状态失败')
  return res.json()
}
