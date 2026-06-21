<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { fetchBooks, deleteBook } from '../api/books'
import type { Book, StatusFilter } from '../types/book'

const router = useRouter()
const { logout, verify } = useAuth()

const books = ref<Book[]>([])
const search = ref('')
const genreFilter = ref('')
const statusFilter = ref<StatusFilter>('')
const loading = ref(false)
const deleteTarget = ref<Book | null>(null)
const deleting = ref(false)

const genres = computed(() => {
  const set = new Set(books.value.map(b => b.genre))
  return Array.from(set).sort()
})

const filteredBooks = computed(() => {
  return books.value.filter(b => {
    if (statusFilter.value && b.status !== statusFilter.value) return false
    if (genreFilter.value && b.genre !== genreFilter.value) return false
    if (search.value) {
      const q = search.value.toLowerCase()
      if (!b.title.toLowerCase().includes(q) && !b.author.toLowerCase().includes(q)) return false
    }
    return true
  })
})

const statusMap: Record<string, string> = {
  done: '已读',
  reading: '在读',
  wish: '想读',
  tobuy: '待购',
  reread: '重读',
}

const genreColors: Record<string, string> = {
  '小说': 'var(--c-novel)',
  '非虚构': 'var(--c-nonfic)',
  '历史': 'var(--c-history)',
  '科学': 'var(--c-science)',
  '技术': 'var(--c-tech)',
  '哲学': 'var(--c-philosophy)',
  '艺术': 'var(--c-art)',
  '商业': 'var(--c-business)',
  '文学': 'var(--c-literature)',
  '传记': 'var(--c-biography)',
  '其他': 'var(--c-other)',
}

async function loadBooks() {
  loading.value = true
  try {
    books.value = await fetchBooks()
  } finally {
    loading.value = false
  }
}

function confirmDelete(book: Book) {
  deleteTarget.value = book
}

async function doDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await deleteBook(deleteTarget.value.id)
    books.value = books.value.filter(b => b.id !== deleteTarget.value!.id)
    deleteTarget.value = null
  } catch (e: any) {
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    }
  } finally {
    deleting.value = false
  }
}

function handleLogout() {
  logout()
  router.push('/admin')
}

onMounted(async () => {
  const valid = await verify()
  if (!valid) {
    router.push('/admin')
    return
  }
  loadBooks()
})
</script>

<template>
  <div class="admin-page">
    <header class="admin-header">
      <div class="admin-header-left">
        <h1>藏书管理</h1>
        <span class="admin-badge">ADMIN</span>
      </div>
      <nav class="admin-nav">
        <RouterLink to="/" class="nav-link">返回书架</RouterLink>
        <button @click="handleLogout" class="nav-link logout">退出登录</button>
      </nav>
    </header>

    <main class="admin-main">
      <div class="toolbar">
        <div class="toolbar-left">
          <input v-model="search" type="text" placeholder="搜索书名或作者" class="search-input" />
          <select v-model="genreFilter" class="filter-select">
            <option value="">全部分类</option>
            <option v-for="g in genres" :key="g" :value="g">{{ g }}</option>
          </select>
          <select v-model="statusFilter" class="filter-select">
            <option value="">全部状态</option>
            <option value="done">已读</option>
            <option value="reading">在读</option>
            <option value="wish">想读</option>
            <option value="tobuy">待购</option>
            <option value="reread">重读</option>
          </select>
        </div>
        <RouterLink to="/admin/books/new" class="add-btn">+ 新增书籍</RouterLink>
      </div>

      <div class="table-wrap">
        <table v-if="!loading && filteredBooks.length > 0">
          <thead>
            <tr>
              <th class="col-emoji">Emoji</th>
              <th class="col-title">书名</th>
              <th class="col-author">作者</th>
              <th class="col-genre">分类</th>
              <th class="col-status">状态</th>
              <th class="col-rating">评分</th>
              <th class="col-actions">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="book in filteredBooks" :key="book.id">
              <td class="col-emoji">{{ book.emoji }}</td>
              <td class="col-title">{{ book.title }}</td>
              <td class="col-author">{{ book.author }}</td>
              <td class="col-genre">
                <span class="genre-tag" :style="{ background: genreColors[book.genre] || 'var(--c-other)' }">
                  {{ book.genre }}
                </span>
              </td>
              <td class="col-status">
                <span class="status-tag" :class="book.status">{{ statusMap[book.status] }}</span>
              </td>
              <td class="col-rating">
                <span v-if="book.rating > 0" class="stars">{{ '★'.repeat(book.rating) }}</span>
                <span v-else class="no-rating">-</span>
              </td>
              <td class="col-actions">
                <RouterLink :to="`/admin/books/${book.id}/edit`" class="action-btn edit">编辑</RouterLink>
                <button @click="confirmDelete(book)" class="action-btn delete">删除</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else-if="loading" class="empty">加载中...</div>
        <div v-else class="empty">没有找到匹配的书籍</div>
      </div>
    </main>

    <Teleport to="body">
      <div v-if="deleteTarget" class="confirm-overlay" @click.self="deleteTarget = null">
        <div class="confirm-card">
          <p>确定删除《{{ deleteTarget.title }}》吗？</p>
          <p class="confirm-sub">此操作不可撤销</p>
          <div class="confirm-actions">
            <button @click="deleteTarget = null" class="confirm-cancel">取消</button>
            <button @click="doDelete" :disabled="deleting" class="confirm-ok">
              {{ deleting ? '删除中...' : '确认删除' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.admin-page {
  min-height: 100vh;
}

.admin-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 32px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}

.admin-header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.admin-header-left h1 {
  font-size: 20px;
  font-weight: 400;
  letter-spacing: 3px;
  color: var(--text);
}

.admin-badge {
  font-size: 10px;
  letter-spacing: 3px;
  color: var(--accent);
  border: 1px solid var(--accent);
  padding: 2px 8px;
  border-radius: 2px;
}

.admin-nav {
  display: flex;
  gap: 16px;
  align-items: center;
}

.nav-link {
  font-size: 13px;
  color: var(--text2);
  text-decoration: none;
  cursor: pointer;
  background: none;
  border: none;
  transition: color .15s;
}

.nav-link:hover {
  color: var(--accent);
}

.nav-link.logout:hover {
  color: var(--danger);
}

.admin-main {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 32px;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  gap: 16px;
  flex-wrap: wrap;
}

.toolbar-left {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
}

.search-input {
  padding: 8px 14px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  width: 220px;
  transition: border-color .15s;
}

.search-input:focus {
  border-color: var(--accent);
}

.filter-select {
  padding: 8px 28px 8px 12px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  cursor: pointer;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%238a8578' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  transition: border-color .15s;
}

.filter-select:focus {
  border-color: var(--accent);
}

.add-btn {
  padding: 8px 20px;
  border-radius: var(--radius);
  background: var(--accent);
  color: #fff;
  font-size: 13px;
  text-decoration: none;
  transition: opacity .15s;
  white-space: nowrap;
}

.add-btn:hover {
  opacity: .9;
}

.table-wrap {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

thead th {
  text-align: left;
  padding: 10px 12px;
  color: var(--text2);
  font-weight: 500;
  font-size: 11px;
  letter-spacing: 1px;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}

tbody td {
  padding: 12px;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.col-emoji { width: 50px; }
.col-title { min-width: 160px; }
.col-author { min-width: 120px; }
.col-genre { width: 80px; }
.col-status { width: 70px; }
.col-rating { width: 80px; }
.col-actions { width: 120px; }

.genre-tag {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 2px;
  font-size: 11px;
  color: rgba(255,255,255,.85);
}

.status-tag {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 2px;
  font-size: 11px;
}

.status-tag.done { background: rgba(106,158,122,.15); color: #6a9e7a; }
.status-tag.reading { background: rgba(92,122,158,.15); color: #5c7a9e; }
.status-tag.wish { background: rgba(158,138,92,.15); color: #9e8a5c; }
.status-tag.tobuy { background: rgba(158,122,90,.15); color: #9e7a5a; }
.status-tag.reread { background: rgba(122,106,158,.15); color: #7a6a9e; }

.stars {
  color: var(--accent);
  letter-spacing: 1px;
}

.no-rating {
  color: var(--text2);
  opacity: .4;
}

.action-btn {
  font-size: 12px;
  padding: 4px 10px;
  border-radius: var(--radius);
  border: none;
  cursor: pointer;
  text-decoration: none;
  transition: opacity .15s;
  margin-right: 6px;
}

.action-btn.edit {
  background: rgba(92,122,158,.15);
  color: #5c7a9e;
}

.action-btn.delete {
  background: rgba(196,90,90,.15);
  color: var(--danger);
}

.action-btn:hover {
  opacity: .8;
}

.empty {
  text-align: center;
  padding: 60px 0;
  color: var(--text2);
  font-size: 14px;
}

.confirm-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  background: rgba(0,0,0,.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
}

.confirm-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 28px 32px;
  max-width: 360px;
  width: 100%;
  text-align: center;
}

.confirm-card p {
  font-size: 15px;
  color: var(--text);
  margin-bottom: 4px;
}

.confirm-sub {
  font-size: 12px;
  color: var(--text2);
  margin-bottom: 20px;
}

.confirm-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
}

.confirm-cancel,
.confirm-ok {
  padding: 8px 20px;
  border-radius: var(--radius);
  font-size: 13px;
  cursor: pointer;
  border: none;
  transition: opacity .15s;
}

.confirm-cancel {
  background: var(--surface-light);
  color: var(--text2);
}

.confirm-ok {
  background: var(--danger);
  color: #fff;
}

.confirm-ok:disabled {
  opacity: .5;
  cursor: not-allowed;
}

@media (max-width: 600px) {
  .admin-header {
    padding: 16px 20px;
    flex-direction: column;
    gap: 12px;
  }
  .admin-main {
    padding: 16px 20px;
  }
  .toolbar {
    flex-direction: column;
    align-items: stretch;
  }
  .toolbar-left {
    flex-direction: column;
  }
  .search-input {
    width: 100%;
  }
  .filter-select {
    width: 100%;
  }
}
</style>
