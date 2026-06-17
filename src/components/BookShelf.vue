<script setup lang="ts">
import { useBooks } from '../composables/useBooks'
import BookCard from './BookCard.vue'
import type { Book } from '../types/book'
import { inject, ref, onMounted, onUnmounted, nextTick, watch } from 'vue'

const { groupedBooks } = useBooks()
const selectBook = inject<(book: Book) => void>('selectBook')!

const genreClass: Record<string, string> = {
  '小说': 'novel', '技术': 'tech', '历史': 'history', '哲学': 'philosophy',
  '科学': 'science', '商业': 'business', '非虚构': 'nonfic', '文学': 'literature', '艺术': 'art',
}

const shelfBodies = ref<Map<string, HTMLElement>>(new Map())
const boards = ref<Map<string, number[]>>(new Map())

let observer: ResizeObserver | null = null

function setShelfBody(el: any, genre: string) {
  if (el) shelfBodies.value.set(genre, el as HTMLElement)
}

function computeBoards() {
  const newBoards = new Map<string, number[]>()
  for (const [genre, el] of shelfBodies.value) {
    const books = el.querySelectorAll<HTMLElement>('.book')
    if (books.length === 0) {
      newBoards.set(genre, [])
      continue
    }
    const rows: number[] = []
    let lastTop = -1
    for (const book of books) {
      const top = book.offsetTop
      if (top !== lastTop) {
        lastTop = top
        rows.push(top)
      }
    }
    const spineEl = books[0].querySelector<HTMLElement>('.book-spine')
    const spineH = spineEl ? spineEl.offsetHeight : 190
    const tops = rows.map(r => r + spineH)
    newBoards.set(genre, tops)
  }
  boards.value = newBoards
}

function setupObserver() {
  observer = new ResizeObserver(() => {
    computeBoards()
  })
  for (const [, el] of shelfBodies.value) {
    observer!.observe(el)
  }
}

onMounted(() => {
  nextTick(() => {
    computeBoards()
    setupObserver()
  })
})

onUnmounted(() => {
  observer?.disconnect()
})

watch(() => groupedBooks.value, () => {
  nextTick(() => {
    observer?.disconnect()
    computeBoards()
    setupObserver()
  })
}, { deep: true })
</script>

<template>
  <section
    v-for="(books, genre) in groupedBooks"
    :key="genre"
    class="shelf-section"
    :data-genre="genre"
  >
    <div class="shelf-header" :class="genreClass[genre] || ''">
      <h2>{{ genre }}</h2>
      <span class="count">{{ books.length }} 本</span>
    </div>
    <div class="shelf-body" :ref="(el) => setShelfBody(el, genre)">
      <div class="shelf-grid">
        <BookCard
          v-for="book in books"
          :key="book.id"
          :book="book"
          @click="selectBook(book)"
        />
      </div>
      <div class="shelf-boards">
        <div
          v-for="top in (boards.get(genre) || [])"
          :key="top"
          class="shelf-board"
          :style="{ top: top + 'px' }"
        ></div>
      </div>
    </div>
  </section>
  <div v-if="Object.keys(groupedBooks).length === 0" class="empty">
    没有找到匹配的书籍
  </div>
</template>

<style scoped>
.shelf-section {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  margin-bottom: 32px;
}

.shelf-header {
  flex: 0 0 80px;
  padding-top: 6px;
  position: sticky;
  top: 20px;
  padding-right: 12px;
  border-right: 1px solid var(--border);
  position: relative;
}
.shelf-header::before {
  content: '';
  position: absolute;
  left: -1px;
  top: 4px;
  bottom: 4px;
  width: 3px;
  border-radius: 2px;
}
.shelf-header.novel::before { background: var(--c-novel); }
.shelf-header.tech::before { background: var(--c-tech); }
.shelf-header.history::before { background: var(--c-history); }
.shelf-header.philosophy::before { background: var(--c-philosophy); }
.shelf-header.science::before { background: var(--c-science); }
.shelf-header.business::before { background: var(--c-business); }
.shelf-header.nonfic::before { background: var(--c-nonfic); }
.shelf-header.literature::before { background: var(--c-literature); }
.shelf-header.art::before { background: var(--c-art); }

.shelf-header h2 {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.3;
  color: var(--wood);
  padding-left: 10px;
}
.shelf-header .count {
  font-size: 11px;
  color: var(--text2);
  display: block;
  margin-top: 1px;
  padding-left: 10px;
}

.shelf-body {
  flex: 1;
  min-width: 0;
  position: relative;
}

.shelf-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16px 8px;
  align-items: flex-end;
}

.shelf-boards {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.shelf-board {
  position: absolute;
  left: 0;
  width: 100%;
  height: 6px;
  background: linear-gradient(to bottom, var(--wood), var(--wood-dark));
  box-shadow: 0 3px 6px rgba(0,0,0,.25);
}

.empty {
  text-align: center;
  padding: 80px 0;
  color: var(--text2);
  font-size: 16px;
}

@media (max-width: 600px) {
  .shelf-section { flex-direction: column; gap: 12px; }
  .shelf-header {
    flex: unset;
    position: static;
    border-right: none;
    border-bottom: 1px solid var(--border);
    padding-right: 0;
    padding-bottom: 8px;
  }
  .shelf-header::before { display: none; }
  .shelf-header h2, .shelf-header .count { padding-left: 0; }
  .shelf-grid { gap: 16px 6px; }
  .shelf-header h2 { font-size: 13px; }
}
</style>
