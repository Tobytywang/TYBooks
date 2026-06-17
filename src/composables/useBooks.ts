import { ref, watch, computed } from 'vue'
import type { Book, Stats, StatusFilter, SortKey } from '../types/book'
import { fetchBooks, fetchStats } from '../api/books'

const books = ref<Book[]>([])
const stats = ref<Stats>({ total: 0, done: 0, reading: 0, wish: 0, byGenre: [] })
const loading = ref(false)

const search = ref('')
const genreFilter = ref('')
const statusFilter = ref<StatusFilter>('')
const sortBy = ref<SortKey>('id')

const genres = computed(() => {
  const set = new Set(books.value.map(b => b.genre))
  return Array.from(set)
})

const groupedBooks = computed(() => {
  const groups: Record<string, Book[]> = {}
  const filtered = books.value.filter(b => {
    if (statusFilter.value && b.status !== statusFilter.value) return false
    if (genreFilter.value && b.genre !== genreFilter.value) return false
    if (search.value) {
      const q = search.value.toLowerCase()
      if (!b.title.toLowerCase().includes(q) && !b.author.toLowerCase().includes(q)) return false
    }
    return true
  })

  const sorted = [...filtered].sort((a, b) => {
    if (sortBy.value === 'title') return a.title.localeCompare(b.title, 'zh')
    if (sortBy.value === 'rating') return b.rating - a.rating
    return a.id - b.id
  })

  for (const book of sorted) {
    if (!groups[book.genre]) groups[book.genre] = []
    groups[book.genre].push(book)
  }
  return groups
})

async function loadBooks() {
  loading.value = true
  try {
    books.value = await fetchBooks()
  } finally {
    loading.value = false
  }
}

async function loadStats() {
  stats.value = await fetchStats()
}

async function refresh() {
  await Promise.all([loadBooks(), loadStats()])
}

export function useBooks() {
  return {
    books,
    stats,
    loading,
    search,
    genreFilter,
    statusFilter,
    sortBy,
    genres,
    groupedBooks,
    loadBooks,
    loadStats,
    refresh,
  }
}
