<script setup lang="ts">
import Header from './components/Header.vue'
import BookShelf from './components/BookShelf.vue'
import BookDetail from './components/BookDetail.vue'
import StatsPanel from './components/StatsPanel.vue'
import { useBooks } from './composables/useBooks'
import { provide, ref } from 'vue'
import type { Book } from './types/book'

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
  <BookDetail v-if="selectedBook" :book="selectedBook" @close="selectedBook = null" />
</template>

<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg: #1a1a2e;
  --surface: #16213e;
  --surface-light: #1f3050;
  --text: #e8e8e8;
  --text2: #8b8fa3;
  --border: #2a3a5c;
  --accent: #e94560;
  --gold: #fbbf24;
  --shadow: 0 2px 8px rgba(0,0,0,.3);
  --radius: 10px;
  --c-novel: #e94560;
  --c-nonfic: #f59e0b;
  --c-history: #8b5cf6;
  --c-science: #06b6d4;
  --c-tech: #3b82f6;
  --c-philosophy: #a855f7;
  --c-art: #ec4899;
  --c-business: #14b8a6;
  --c-literature: #f97316;
}

body {
  font-family: "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", -apple-system, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
}

.container { max-width: 1600px; margin: 0 auto; padding: 0 32px; }
</style>
