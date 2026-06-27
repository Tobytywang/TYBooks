<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { fetchStatus } from '../api/status'
import type { SystemStatus, QueryLogItem, ServerLogItem } from '../api/status'

const router = useRouter()
const { logout, verify } = useAuth()

const status = ref<SystemStatus | null>(null)
const loading = ref(false)
const error = ref('')
const autoRefresh = ref(true)
const canRefresh = ref(true)
let timer: ReturnType<typeof setInterval> | null = null

const frontendInfo = computed(() => ({
  url: window.location.href,
  mode: import.meta.env.DEV ? 'development' : 'production',
  userAgent: navigator.userAgent.split(' ').slice(-2).join(' '),
  platform: navigator.platform,
  language: navigator.language,
}))

const logSortKey = ref<'time' | 'duration'>('time')
const logSortAsc = ref(false)
const activeLogTab = ref<'database' | 'server'>('database')

const sortedLog = computed(() => {
  if (!status.value?.queryLog) return []
  const list = [...status.value.queryLog]
  const dir = logSortAsc.value ? 1 : -1
  if (logSortKey.value === 'time') {
    list.sort((a, b) => {
      const cmp = new Date(a.time).getTime() - new Date(b.time).getTime()
      return cmp !== 0 ? dir * cmp : dir * (a.id - b.id)
    })
  } else {
    list.sort((a, b) => {
      const cmp = a.duration - b.duration
      return cmp !== 0 ? dir * cmp : dir * (a.id - b.id)
    })
  }
  return list
})

function toggleLogSort(key: 'time' | 'duration') {
  if (logSortKey.value === key) {
    logSortAsc.value = !logSortAsc.value
  } else {
    logSortKey.value = key
    logSortAsc.value = key === 'duration'
  }
}

const serverLogSortAsc = ref(false)

const sortedServerLog = computed(() => {
  if (!status.value?.serverLog) return []
  const list = [...status.value.serverLog]
  const dir = serverLogSortAsc.value ? 1 : -1
  list.sort((a, b) => dir * (new Date(a.time).getTime() - new Date(b.time).getTime()))
  return list
})

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}h ${m}m ${s}s`
  if (m > 0) return `${m}m ${s}s`
  return `${s}s`
}

function formatTime(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleTimeString('zh-CN', { hour12: false })
}

async function loadStatus() {
  if (!canRefresh.value) return
  canRefresh.value = false
  loading.value = true
  error.value = ''
  try {
    status.value = await fetchStatus()
  } catch (e: any) {
    error.value = e.message || '获取状态失败'
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    }
  } finally {
    loading.value = false
    setTimeout(() => { canRefresh.value = true }, 1000)
  }
}

function toggleAutoRefresh() {
  autoRefresh.value = !autoRefresh.value
  if (autoRefresh.value) {
    timer = setInterval(loadStatus, 10000)
  } else if (timer) {
    clearInterval(timer)
    timer = null
  }
}

onMounted(async () => {
  const valid = await verify()
  if (!valid) {
    router.push('/admin')
    return
  }
  await loadStatus()
  timer = setInterval(loadStatus, 10000)
})

onUnmounted(() => {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
})
</script>

<template>
  <main class="status-main">
    <div class="admin-toolbar">
      <div class="toolbar-left">
        <span class="admin-toolbar-title">系统状态</span>
      </div>
      <div class="toolbar-right">
        <button @click="toggleAutoRefresh" class="ctrl-btn" :class="{ active: autoRefresh }">
          {{ autoRefresh ? '自动刷新: 开' : '自动刷新: 关' }}
        </button>
        <button @click="loadStatus" :disabled="!canRefresh" class="ctrl-btn-accent">
          {{ loading ? '刷新中...' : '手动刷新' }}
        </button>
      </div>
    </div>

    <div v-if="error" class="status-error">{{ error }}</div>

    <div class="status-cards">
      <div class="status-card">
        <div class="card-header">
          <span class="card-dot ok"></span>
          <span class="card-title">前端</span>
        </div>
        <div class="card-body">
          <div class="card-row"><span class="card-label">状态</span><span class="card-value ok-text">运行中</span></div>
          <div class="card-row"><span class="card-label">模式</span><span class="card-value">{{ frontendInfo.mode }}</span></div>
          <div class="card-row"><span class="card-label">页面</span><span class="card-value mono">{{ frontendInfo.url }}</span></div>
          <div class="card-row"><span class="card-label">平台</span><span class="card-value">{{ frontendInfo.platform }}</span></div>
          <div class="card-row"><span class="card-label">语言</span><span class="card-value">{{ frontendInfo.language }}</span></div>
        </div>
      </div>

      <div class="status-card">
        <div class="card-header">
          <span class="card-dot" :class="status?.backend?.status === 'ok' ? 'ok' : 'err'"></span>
          <span class="card-title">后端</span>
        </div>
        <div class="card-body">
          <div class="card-row"><span class="card-label">状态</span><span class="card-value" :class="status?.backend?.status === 'ok' ? 'ok-text' : 'err-text'">{{ status?.backend?.status === 'ok' ? '运行中' : '异常' }}</span></div>
          <div class="card-row"><span class="card-label">运行时间</span><span class="card-value">{{ status?.backend?.uptime ? formatUptime(status.backend.uptime) : '-' }}</span></div>
          <div class="card-row"><span class="card-label">Node 版本</span><span class="card-value mono">{{ status?.backend?.nodeVersion || '-' }}</span></div>
          <div class="card-row"><span class="card-label">端口</span><span class="card-value mono">{{ status?.backend?.port || '-' }}</span></div>
        </div>
      </div>

      <div class="status-card">
        <div class="card-header">
          <span class="card-dot" :class="status?.database?.status === 'ok' ? 'ok' : 'err'"></span>
          <span class="card-title">数据库</span>
        </div>
        <div class="card-body">
          <div class="card-row"><span class="card-label">状态</span><span class="card-value" :class="status?.database?.status === 'ok' ? 'ok-text' : 'err-text'">{{ status?.database?.status === 'ok' ? '运行中' : '异常' }}</span></div>
          <div class="card-row"><span class="card-label">响应时延</span><span class="card-value mono">{{ status?.database?.latency != null ? status.database.latency + ' ms' : '-' }}</span></div>
          <div class="card-row"><span class="card-label">PG 版本</span><span class="card-value mono">{{ status?.database?.pgVersion || '-' }}</span></div>
          <div class="card-row"><span class="card-label">连接池</span><span class="card-value">{{ status?.database?.poolTotal != null ? `${status.database.poolIdle} 空闲 / ${status.database.poolTotal} 总计` : '-' }}</span></div>
          <div class="card-row"><span class="card-label">等待中</span><span class="card-value">{{ status?.database?.poolWaiting ?? '-' }}</span></div>
        </div>
      </div>
    </div>

    <div class="log-section">
      <div class="log-header">
        <div class="log-tabs">
          <button class="log-tab" :class="{ active: activeLogTab === 'database' }" @click="activeLogTab = 'database'">数据库日志</button>
          <button class="log-tab" :class="{ active: activeLogTab === 'server' }" @click="activeLogTab = 'server'">后端日志</button>
        </div>
        <span class="log-count">{{ activeLogTab === 'database' ? sortedLog.length : sortedServerLog.length }} 条</span>
      </div>

      <div v-if="activeLogTab === 'database'" class="table-wrap">
        <table v-if="sortedLog.length > 0">
          <thead>
            <tr>
              <th class="col-id">ID</th>
              <th class="col-time sortable" @click="toggleLogSort('time')">
                时间 <span class="sort-icon">{{ logSortKey === 'time' ? (logSortAsc ? '↑' : '↓') : '' }}</span>
              </th>
              <th class="col-sql">SQL</th>
              <th class="col-duration sortable" @click="toggleLogSort('duration')">
                时延 <span class="sort-icon">{{ logSortKey === 'duration' ? (logSortAsc ? '↑' : '↓') : '' }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, i) in sortedLog" :key="i">
              <td class="col-id">{{ item.id }}</td>
              <td class="col-time">{{ formatTime(item.time) }}</td>
              <td class="col-sql"><code>{{ item.sql }}</code></td>
              <td class="col-duration" :class="{ slow: item.duration > 50 }">{{ item.duration }} ms</td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty">暂无查询记录</div>
      </div>

      <div v-else class="table-wrap">
        <table v-if="sortedServerLog.length > 0">
          <thead>
            <tr>
              <th class="col-time sortable" @click="serverLogSortAsc = !serverLogSortAsc">
                时间 <span class="sort-icon">{{ serverLogSortAsc ? '↑' : '↓' }}</span>
              </th>
              <th class="col-level">级别</th>
              <th class="col-message">消息</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, i) in sortedServerLog" :key="i">
              <td class="col-time">{{ formatTime(item.time) }}</td>
              <td class="col-level"><span class="level-tag" :class="item.level">{{ item.level }}</span></td>
              <td class="col-message"><code>{{ item.message }}</code></td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty">暂无后端日志</div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.status-main {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 32px;
}

.toolbar-right {
  display: flex;
  gap: 10px;
  align-items: center;
}

.status-error {
  text-align: center;
  padding: 12px 16px;
  margin-bottom: 16px;
  color: var(--danger);
  background: rgba(196,90,90,.1);
  border-radius: var(--radius);
  font-size: 13px;
}

.status-cards {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 24px;
}

.status-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border);
}

.card-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.card-dot.ok { background: #6a9e7a; }
.card-dot.err { background: var(--danger); }

.card-title {
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 1px;
  color: var(--text);
}

.card-body {
  padding: 12px 16px;
}

.card-row {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding: 4px 0;
  font-size: 12px;
}

.card-label {
  color: var(--text2);
  flex-shrink: 0;
  margin-right: 12px;
}

.card-value {
  color: var(--text);
  text-align: right;
  word-break: break-all;
}

.card-value.mono {
  font-family: monospace;
  font-size: 11px;
}

.ok-text { color: #6a9e7a; }
.err-text { color: var(--danger); }

.log-section {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}

.log-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  border-bottom: 1px solid var(--border);
}

.log-tabs {
  display: flex;
  gap: 0;
}

.log-tab {
  padding: 10px 16px;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 1px;
  color: var(--text2);
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  transition: all .15s;
}

.log-tab:hover {
  color: var(--text);
}

.log-tab.active {
  color: var(--accent);
  border-bottom-color: var(--accent);
}

.log-count {
  font-weight: 400;
  color: var(--text2);
  font-size: 11px;
}

.table-wrap {
  overflow-x: auto;
  max-height: 400px;
  overflow-y: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

thead th {
  position: sticky;
  top: 0;
  background: var(--surface);
  text-align: left;
  padding: 6px 10px;
  color: var(--text2);
  font-weight: 500;
  font-size: 11px;
  letter-spacing: 1px;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
  z-index: 1;
}

thead th.sortable {
  cursor: pointer;
  user-select: none;
}

thead th.sortable:hover {
  color: var(--accent);
}

.sort-icon {
  font-size: 10px;
  margin-left: 2px;
}

tbody td {
  padding: 4px 10px;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.col-id { width: 50px; text-align: center; }
.col-time { width: 80px; white-space: nowrap; }
.col-sql { min-width: 200px; }
.col-sql code {
  font-family: monospace;
  font-size: 11px;
  color: var(--text2);
  background: var(--bg);
  padding: 1px 4px;
  border-radius: 2px;
}
.col-duration { width: 80px; text-align: right; white-space: nowrap; font-family: monospace; font-size: 11px; }
.col-duration.slow { color: var(--danger); }

.col-level { width: 60px; }
.level-tag {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 2px;
  font-size: 11px;
  font-family: monospace;
}
.level-tag.info { background: rgba(92,122,158,.15); color: #5c7a9e; }
.level-tag.warn { background: rgba(158,138,92,.15); color: #9e8a5c; }
.level-tag.error { background: rgba(196,90,90,.15); color: var(--danger); }

.col-message { min-width: 200px; }
.col-message code {
  font-family: monospace;
  font-size: 11px;
  color: var(--text2);
  background: var(--bg);
  padding: 1px 4px;
  border-radius: 2px;
  white-space: pre-wrap;
  word-break: break-all;
}

.empty {
  text-align: center;
  padding: 40px 0;
  color: var(--text2);
  font-size: 13px;
}

.ctrl-btn-accent:disabled {
  opacity: .4;
  cursor: not-allowed;
}

@media (max-width: 900px) {
  .status-cards {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 600px) {
  .status-main {
    padding: 16px 20px;
  }
  .toolbar-right {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
