<script setup lang="ts">
import Header from '../components/Header.vue'
import BookShelf from '../components/BookShelf.vue'
import BookDetail from '../components/BookDetail.vue'
import StatsPanel from '../components/StatsPanel.vue'
import { useBooks } from '../composables/useBooks'
import { provide, ref } from 'vue'
import type { Book } from '../types/book'

const { refresh, dbError } = useBooks()
refresh()

const selectedBook = ref<Book | null>(null)
provide('selectBook', (book: Book) => {
  selectedBook.value = book
})
</script>

<template>
  <Header />
  <main class="container">
    <div v-if="dbError" class="db-error">{{ dbError }}</div>
    <StatsPanel />
    <BookShelf />
  </main>
  <Transition name="book-overlay">
    <BookDetail v-if="selectedBook" :book="selectedBook" @close="selectedBook = null" />
  </Transition>
</template>

<style scoped>
.db-error {
  text-align: center;
  padding: 12px 16px;
  margin-bottom: 16px;
  color: var(--danger);
  background: rgba(196,90,90,.1);
  border-radius: var(--radius);
  font-size: 13px;
}
</style>
