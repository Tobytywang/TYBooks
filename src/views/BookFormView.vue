<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { fetchBook, createBook, updateBook } from '../api/books'
import BookForm from '../components/BookForm.vue'
import type { Book, BookCreate } from '../types/book'

const router = useRouter()
const route = useRoute()
const { logout, verify } = useAuth()

const isEdit = computed(() => !!route.params.id)
const pageTitle = computed(() => isEdit.value ? '编辑书籍' : '新增书籍')

const existingBook = ref<Book | undefined>()
const form = ref<BookCreate>({
  emoji: '📖',
  title: '',
  author: '',
  genre: '',
  status: 'wish',
  rating: 0,
  review: '',
  tags: '',
})

const saving = ref(false)
const error = ref('')

async function loadBook() {
  const id = Number(route.params.id)
  if (!id) return
  try {
    const book = await fetchBook(id)
    existingBook.value = book
    form.value = {
      emoji: book.emoji,
      title: book.title,
      author: book.author,
      genre: book.genre,
      status: book.status,
      rating: book.rating,
      review: book.review,
      tags: book.tags,
    }
  } catch {
    error.value = '书籍不存在'
  }
}

async function onSubmit(data: BookCreate) {
  error.value = ''
  saving.value = true
  try {
    if (isEdit.value && existingBook.value) {
      await updateBook(existingBook.value.id, data)
    } else {
      await createBook(data)
    }
    router.push('/admin/dashboard')
  } catch (e: any) {
    if (e.message?.includes('未登录')) {
      logout()
      router.push('/admin')
    } else {
      error.value = e.message || '保存失败'
    }
  } finally {
    saving.value = false
  }
}

function onCancel() {
  router.push('/admin/dashboard')
}

onMounted(async () => {
  const valid = await verify()
  if (!valid) {
    router.push('/admin')
    return
  }
  if (isEdit.value) {
    loadBook()
  }
})
</script>

<template>
  <div class="form-page">
    <header class="form-header">
      <div class="form-header-left">
        <RouterLink to="/admin/dashboard" class="back-link">&larr; 返回管理</RouterLink>
        <h1>{{ pageTitle }}</h1>
      </div>
    </header>

    <main class="form-main">
      <div v-if="error" class="form-error">{{ error }}</div>
      <BookForm
        :book="existingBook"
        v-model:form="form"
        @submit="onSubmit"
        @cancel="onCancel"
      />
      <div v-if="saving" class="saving-hint">正在保存...</div>
    </main>
  </div>
</template>

<style scoped>
.form-page {
  min-height: 100vh;
}

.form-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 32px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}

.form-header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.back-link {
  font-size: 13px;
  color: var(--text2);
  text-decoration: none;
  transition: color .15s;
}

.back-link:hover {
  color: var(--accent);
}

.form-header h1 {
  font-size: 20px;
  font-weight: 400;
  letter-spacing: 3px;
  color: var(--text);
}

.form-main {
  max-width: 1400px;
  margin: 0 auto;
  padding: 32px;
}

.form-error {
  color: var(--danger);
  font-size: 13px;
  margin-bottom: 16px;
  padding: 10px 14px;
  background: rgba(196,90,90,.1);
  border-radius: var(--radius);
}

.saving-hint {
  text-align: center;
  color: var(--text2);
  font-size: 13px;
  margin-top: 16px;
}

@media (max-width: 600px) {
  .form-header {
    padding: 16px 20px;
  }
  .form-main {
    padding: 20px;
  }
}
</style>
