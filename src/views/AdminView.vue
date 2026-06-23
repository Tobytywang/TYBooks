<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { fetchBooksPaged, fetchBooks, deleteBook } from '../api/books'
import { fetchGenres } from '../api/genres'
import type { Book, StatusFilter, PaginatedBooks } from '../types/book'

const router = useRouter()
const { logout, verify } = useAuth()

const books = ref<Book[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const totalPages = computed(() => Math.ceil(total.value / pageSize.value))

const search = ref('')
const genreFilter = ref('')
const statusFilter = ref<StatusFilter>('')
const loading = ref(false)
const deleteTarget = ref<Book | null>(null)
const deleting = ref(false)

const genres = ref<string[]>([])

const pageSizes = [10, 20, 50, 100]

const pageNumbers = computed(() => {
  const t = totalPages.value
  const p = page.value
  const pages: (number | string)[] = []
  if (t <= 7) {
    for (let i = 1; i <= t; i++) pages.push(i)
  } else {
    pages.push(1)
    if (p > 3) pages.push('...')
    const start = Math.max(2, p - 1)
    const end = Math.min(t - 1, p + 1)
    for (let i = start; i <= end; i++) pages.push(i)
    if (p < t - 2) pages.push('...')
    pages.push(t)
  }
  return pages
})

async function loadBooks() {
  loading.value = true
  try {
    const result: PaginatedBooks = await fetchBooksPaged({
      search: search.value || undefined,
      genre: genreFilter.value || undefined,
      status: statusFilter.value || undefined,
      page: page.value,
      pageSize: pageSize.value,
    })
    books.value = result.data
    total.value = result.total
  } finally {
    loading.value = false
  }
}

async function loadGenres() {
  const list = await fetchGenres()
  genres.value = list.map(g => g.name)
}

function confirmDelete(book: Book) {
  deleteTarget.value = book
}

async function doDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await deleteBook(deleteTarget.value.id)
    deleteTarget.value = null
    loadBooks()
  } catch (e: any) {
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    }
  } finally {
    deleting.value = false
  }
}

function goToPage(p: number | string) {
  if (typeof p === 'string') return
  page.value = p
}

watch([search, genreFilter, statusFilter], () => {
  page.value = 1
  loadBooks()
})

watch(pageSize, () => {
  page.value = 1
  loadBooks()
})

watch(page, () => {
  loadBooks()
})

onMounted(async () => {
  const valid = await verify()
  if (!valid) {
    router.push('/admin')
    return
  }
  loadGenres()
  loadBooks()
})
</script>

<template>
  <main class="admin-main">
    <div class="toolbar">
      <div class="toolbar-left">
        <input v-model="search" type="text" placeholder="搜索书名或作者" class="ctrl-input" style="width: 220px" />
        <select v-model="genreFilter" class="ctrl-select">
          <option value="">全部分类</option>
          <option v-for="g in genres" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="statusFilter" class="ctrl-select">
          <option value="">全部状态</option>
          <option value="done">已读</option>
          <option value="reading">在读</option>
          <option value="wish">想读</option>
          <option value="tobuy">待购</option>
          <option value="reread">重读</option>
        </select>
      </div>
      <RouterLink to="/admin/books/new" class="ctrl-btn-accent">+ 新增书籍</RouterLink>
    </div>

    <div class="table-wrap">
      <table v-if="!loading && books.length > 0">
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
          <tr v-for="book in books" :key="book.id">
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
              <div class="action-group">
                <RouterLink :to="`/admin/books/${book.id}/edit`" class="action-btn edit">编辑</RouterLink>
                <button @click="confirmDelete(book)" class="action-btn delete">删除</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else-if="loading" class="empty">加载中...</div>
      <div v-else class="empty">没有找到匹配的书籍</div>
    </div>

    <div v-if="total > 0" class="pagination">
      <span class="pag-total">共 {{ total }} 条</span>
      <div class="pag-size">
        <span class="pag-size-label">每页</span>
        <select v-model="pageSize" class="pag-size-select">
          <option v-for="s in pageSizes" :key="s" :value="s">{{ s }}</option>
        </select>
        <span class="pag-size-label">条</span>
      </div>
      <div class="pag-nav">
        <button class="pag-btn" :disabled="page <= 1" @click="goToPage(page - 1)">&lsaquo;</button>
        <template v-for="p in pageNumbers" :key="p">
          <span v-if="p === '...'" class="pag-ellipsis">...</span>
          <button
            v-else
            class="pag-btn"
            :class="{ active: p === page }"
            @click="goToPage(p)"
          >{{ p }}</button>
        </template>
        <button class="pag-btn" :disabled="page >= totalPages" @click="goToPage(page + 1)">&rsaquo;</button>
      </div>
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
</template>

<script lang="ts">
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
</script>

<style scoped>
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
  padding: 6px 10px;
  color: var(--text2);
  font-weight: 500;
  font-size: 11px;
  letter-spacing: 1px;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}

tbody td {
  padding: 6px 10px;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.col-emoji { width: 50px; }
.col-title { min-width: 160px; }
.col-author { min-width: 120px; }
.col-genre { width: 80px; }
.col-status { width: 70px; }
.col-rating { width: 80px; }
.col-actions { width: 110px; white-space: nowrap; }

.genre-tag {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 2px;
  font-size: 11px;
  color: rgba(255,255,255,.85);
}

.status-tag {
  display: inline-block;
  padding: 1px 8px;
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
  font-size: 11px;
  padding: 2px 8px;
  border-radius: var(--radius);
  border: none;
  cursor: pointer;
  text-decoration: none;
  transition: opacity .15s;
  white-space: nowrap;
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

.action-group {
  display: flex;
  gap: 4px;
}

.empty {
  text-align: center;
  padding: 60px 0;
  color: var(--text2);
  font-size: 14px;
}

.pagination {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-top: 16px;
  flex-wrap: wrap;
}

.pag-total {
  font-size: 12px;
  color: var(--text2);
}

.pag-size {
  display: flex;
  align-items: center;
  gap: 6px;
}

.pag-size-label {
  font-size: 12px;
  color: var(--text2);
}

.pag-size-select {
  padding: 4px 20px 4px 8px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 12px;
  outline: none;
  cursor: pointer;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 24 24' fill='none' stroke='%238a8578' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 6px center;
}

.pag-nav {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
}

.pag-btn {
  min-width: 30px;
  height: 30px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--text2);
  font-size: 12px;
  cursor: pointer;
  transition: all .15s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.pag-btn:hover:not(:disabled) {
  border-color: var(--accent);
  color: var(--accent);
}

.pag-btn:disabled {
  opacity: .3;
  cursor: not-allowed;
}

.pag-btn.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}

.pag-ellipsis {
  font-size: 12px;
  color: var(--text2);
  padding: 0 4px;
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
  .pagination {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }
  .pag-nav {
    margin-left: 0;
    justify-content: center;
    flex-wrap: wrap;
  }
}
</style>
