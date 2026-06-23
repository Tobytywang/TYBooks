<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { fetchGenres, createGenre, updateGenre, deleteGenre } from '../api/genres'
import type { Genre } from '../types/book'

const router = useRouter()
const { logout, verify } = useAuth()

const genres = ref<Genre[]>([])
const loading = ref(false)

const showForm = ref(false)
const editingGenre = ref<Genre | null>(null)
const formName = ref('')
const formColor = ref('var(--c-other)')
const formSortOrder = ref(0)
const formError = ref('')
const saving = ref(false)

const deleteTarget = ref<Genre | null>(null)
const deleting = ref(false)
const deleteError = ref('')

const presetColors = [
  'var(--c-novel)', 'var(--c-nonfic)', 'var(--c-history)',
  'var(--c-science)', 'var(--c-tech)', 'var(--c-philosophy)',
  'var(--c-art)', 'var(--c-business)', 'var(--c-literature)',
  'var(--c-biography)', 'var(--c-other)',
]

async function loadGenres() {
  loading.value = true
  try {
    genres.value = await fetchGenres()
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingGenre.value = null
  formName.value = ''
  formColor.value = 'var(--c-other)'
  formSortOrder.value = genres.value.length + 1
  formError.value = ''
  showForm.value = true
}

function openEdit(genre: Genre) {
  editingGenre.value = genre
  formName.value = genre.name
  formColor.value = genre.color
  formSortOrder.value = genre.sort_order
  formError.value = ''
  showForm.value = true
}

function cancelForm() {
  showForm.value = false
  editingGenre.value = null
}

async function submitForm() {
  formError.value = ''
  if (!formName.value.trim()) {
    formError.value = '分类名不能为空'
    return
  }
  saving.value = true
  try {
    if (editingGenre.value) {
      await updateGenre(editingGenre.value.id, {
        name: formName.value.trim(),
        color: formColor.value,
        sort_order: formSortOrder.value,
      })
    } else {
      await createGenre({
        name: formName.value.trim(),
        color: formColor.value,
        sort_order: formSortOrder.value,
      })
    }
    showForm.value = false
    loadGenres()
  } catch (e: any) {
    formError.value = e.message || '保存失败'
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    }
  } finally {
    saving.value = false
  }
}

function confirmDelete(genre: Genre) {
  deleteTarget.value = genre
  deleteError.value = ''
}

async function doDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  deleteError.value = ''
  try {
    await deleteGenre(deleteTarget.value.id)
    deleteTarget.value = null
    loadGenres()
  } catch (e: any) {
    deleteError.value = e.message || '删除失败'
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    }
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  const valid = await verify()
  if (!valid) {
    router.push('/admin')
    return
  }
  loadGenres()
})
</script>

<template>
  <main class="genre-main">
    <div class="admin-toolbar">
      <span class="admin-toolbar-title">分类管理</span>
      <button @click="openCreate" class="ctrl-btn-accent">+ 新增分类</button>
    </div>

    <div class="table-wrap">
      <table v-if="!loading && genres.length > 0">
        <thead>
          <tr>
            <th class="col-name">分类名称</th>
            <th class="col-color">颜色</th>
            <th class="col-order">排序</th>
            <th class="col-actions">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="genre in genres" :key="genre.id">
            <td class="col-name">
              <span class="genre-dot" :style="{ background: genre.color }"></span>
              {{ genre.name }}
            </td>
            <td class="col-color">
              <code class="color-code">{{ genre.color }}</code>
            </td>
            <td class="col-order">{{ genre.sort_order }}</td>
            <td class="col-actions">
              <div class="action-group">
                <button @click="openEdit(genre)" class="action-btn edit">编辑</button>
                <button @click="confirmDelete(genre)" class="action-btn delete">删除</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else-if="loading" class="empty">加载中...</div>
      <div v-else class="empty">暂无分类</div>
    </div>

    <Teleport to="body">
      <div v-if="showForm" class="form-overlay" @click.self="cancelForm">
        <div class="form-card">
          <h3>{{ editingGenre ? '编辑分类' : '新增分类' }}</h3>
          <div class="form-field">
            <label>分类名称 <span class="required">*</span></label>
            <input v-model="formName" type="text" class="ctrl-input" placeholder="如：小说" />
          </div>
          <div class="form-field">
            <label>颜色</label>
            <div class="color-options">
              <span
                v-for="c in presetColors"
                :key="c"
                class="color-option"
                :class="{ active: formColor === c }"
                :style="{ background: c }"
                @click="formColor = c"
              ></span>
            </div>
          </div>
          <div class="form-field">
            <label>排序</label>
            <input v-model.number="formSortOrder" type="number" min="0" class="ctrl-input" style="width: 100px" />
          </div>
          <div v-if="formError" class="form-error">{{ formError }}</div>
          <div class="form-actions">
            <button @click="cancelForm" class="ctrl-btn">取消</button>
            <button @click="submitForm" :disabled="saving" class="ctrl-btn-accent">
              {{ saving ? '保存中...' : '保存' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <Teleport to="body">
      <div v-if="deleteTarget" class="form-overlay" @click.self="deleteTarget = null">
        <div class="form-card">
          <h3>确认删除</h3>
          <p class="confirm-text">确定删除分类「{{ deleteTarget.name }}」吗？</p>
          <p class="confirm-sub">该分类下没有书籍时才可删除</p>
          <div v-if="deleteError" class="form-error">{{ deleteError }}</div>
          <div class="form-actions">
            <button @click="deleteTarget = null" class="ctrl-btn">取消</button>
            <button @click="doDelete" :disabled="deleting" class="ctrl-btn-danger">
              {{ deleting ? '删除中...' : '确认删除' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </main>
</template>

<style scoped>
.genre-main {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 32px;
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

.col-name { min-width: 120px; }
.col-color { min-width: 140px; }
.col-order { width: 60px; }
.col-actions { width: 110px; white-space: nowrap; }

.genre-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 8px;
  vertical-align: middle;
}

.color-code {
  font-size: 11px;
  color: var(--text2);
  background: var(--bg);
  padding: 2px 6px;
  border-radius: 2px;
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

.action-btn:hover { opacity: .8; }

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

.form-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  background: rgba(0,0,0,.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.form-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 24px 28px;
  max-width: 420px;
  width: 100%;
}

.form-card h3 {
  font-size: 15px;
  font-weight: 400;
  letter-spacing: 2px;
  color: var(--text);
  margin-bottom: 20px;
}

.form-field {
  margin-bottom: 16px;
}

.form-field label {
  display: block;
  font-size: 11px;
  color: var(--text2);
  margin-bottom: 4px;
  letter-spacing: 1px;
}

.required { color: var(--danger); }

.color-options {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.color-option {
  width: 24px;
  height: 24px;
  border-radius: 4px;
  cursor: pointer;
  border: 2px solid transparent;
  transition: border-color .15s;
}

.color-option.active {
  border-color: var(--accent);
}

.color-option:hover {
  border-color: var(--text2);
}

.form-error {
  color: var(--danger);
  font-size: 12px;
  margin-bottom: 12px;
}

.form-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  margin-top: 16px;
}

.ctrl-btn-danger {
  display: inline-flex;
  align-items: center;
  padding: 8px 20px;
  border-radius: var(--radius);
  border: none;
  background: var(--danger);
  color: #fff;
  font-size: 13px;
  cursor: pointer;
  transition: opacity .15s;
  white-space: nowrap;
  line-height: 1.4;
}

.ctrl-btn-danger:hover { opacity: .9; }
.ctrl-btn-danger:disabled { opacity: .5; cursor: not-allowed; }

.confirm-text {
  font-size: 14px;
  color: var(--text);
  margin-bottom: 4px;
}

.confirm-sub {
  font-size: 12px;
  color: var(--text2);
  margin-bottom: 16px;
}

@media (max-width: 600px) {
  .genre-main {
    padding: 16px 20px;
  }
  .toolbar {
    flex-direction: column;
    align-items: stretch;
  }
  .toolbar-left {
    flex-direction: column;
  }
}
</style>
