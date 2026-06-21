<script setup lang="ts">
import Header from '../components/Header.vue'
import BookShelf from '../components/BookShelf.vue'
import BookDetail from '../components/BookDetail.vue'
import StatsPanel from '../components/StatsPanel.vue'
import { useBooks } from '../composables/useBooks'
import { provide, ref } from 'vue'
import type { Book } from '../types/book'

const { refresh } = useBooks()
refresh()

const selectedBook = ref<Book | null>(null)
provide('selectBook', (book: Book) => {
  selectedBook.value = book
})
</script>

<template>
  <Header />
  <main class="container">
    <StatsPanel />
    <BookShelf />
  </main>
  <Transition name="book-overlay">
    <BookDetail v-if="selectedBook" :book="selectedBook" @close="selectedBook = null" />
  </Transition>
</template>
