<script setup lang="ts">
import { useBooks } from '../composables/useBooks'
import BookCard from './BookCard.vue'
import type { Book } from '../types/book'
import { inject } from 'vue'

const { groupedBooks } = useBooks()
const selectBook = inject<(book: Book) => void>('selectBook')!

const genreIcons: Record<string, string> = {
  '小说': '📖', '技术': '💻', '历史': '📜', '哲学': '🧠',
  '科学': '🔬', '商业': '💼', '非虚构': '📰', '文学': '📝', '艺术': '🎨',
}

const genreClass: Record<string, string> = {
  '小说': 'novel', '技术': 'tech', '历史': 'history', '哲学': 'philosophy',
  '科学': 'science', '商业': 'business', '非虚构': 'nonfic', '文学': 'literature', '艺术': 'art',
}
</script>

<template>
  <section
    v-for="(books, genre) in groupedBooks"
    :key="genre"
    class="shelf-section"
    :data-genre="genre"
  >
    <div class="shelf-header" :class="genreClass[genre] || ''">
      <h2>{{ genreIcons[genre] || '📚' }} {{ genre }}</h2>
      <span class="count">{{ books.length }} 本</span>
    </div>
    <div class="shelf-grid">
      <BookCard
        v-for="book in books"
        :key="book.id"
        :book="book"
        @click="selectBook(book)"
      />
    </div>
  </section>
  <div v-if="Object.keys(groupedBooks).length === 0" class="empty">
    没有找到匹配的书籍
  </div>
</template>

<style scoped>
.shelf-section {
  display: flex;
  gap: 20px;
  margin-bottom: 32px;
  align-items: flex-start;
}
.shelf-header {
  flex: 0 0 100px;
  padding-top: 6px;
  position: sticky;
  top: 20px;
  border-right: 1px solid var(--border);
  padding-right: 16px;
}
.shelf-header h2 { font-size: 16px; font-weight: 600; line-height: 1.3; }
.shelf-header .count { font-size: 12px; color: var(--text2); display: block; margin-top: 2px; }

.shelf-header.novel h2 { color: var(--c-novel); }
.shelf-header.tech h2 { color: var(--c-tech); }
.shelf-header.history h2 { color: var(--c-history); }
.shelf-header.philosophy h2 { color: var(--c-philosophy); }
.shelf-header.science h2 { color: var(--c-science); }
.shelf-header.business h2 { color: var(--c-business); }
.shelf-header.nonfic h2 { color: var(--c-nonfic); }
.shelf-header.literature h2 { color: var(--c-literature); }
.shelf-header.art h2 { color: var(--c-art); }

.shelf-grid {
  flex: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
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
  .shelf-grid { gap: 10px; }
}
</style>
