<script setup lang="ts">
import type { Book } from '../types/book'

defineProps<{ book: Book }>()
const emit = defineEmits<{ click: [] }>()

const genreColors: Record<string, string> = {
  '小说': '#e94560',
  '非虚构': '#f59e0b',
  '历史': '#8b5cf6',
  '科学': '#06b6d4',
  '技术': '#3b82f6',
  '哲学': '#a855f7',
  '艺术': '#ec4899',
  '商业': '#14b8a6',
  '文学': '#f97316',
  '传记': '#6366f1',
  '其他': '#6b7280',
}

const statusEmoji: Record<string, string> = {
  done: '✅',
  reading: '📖',
  wish: '📌',
}
</script>

<template>
  <div class="book" :data-genre="book.genre" @click="emit('click')">
    <div
      class="book-spine"
      :style="{ background: `linear-gradient(135deg, ${genreColors[book.genre] || '#6b7280'}, ${genreColors[book.genre] || '#4b5563'}dd)` }"
    >
      <span class="book-ribbon">{{ statusEmoji[book.status] }}</span>
      <span class="book-emoji">{{ book.emoji }}</span>
      <span class="book-title-on-spine">{{ book.title }}</span>
    </div>
    <div class="book-author-label">{{ book.author }}</div>
  </div>
</template>

<style scoped>
.book {
  width: 150px;
  cursor: pointer;
  transition: transform .2s;
  position: relative;
}
.book:hover { transform: translateY(-6px); }
.book:active { transform: scale(.96); }

.book-spine {
  width: 100%;
  height: 190px;
  border-radius: 6px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  transition: box-shadow .2s;
}
.book:hover .book-spine { box-shadow: 0 8px 24px rgba(0,0,0,.4); }

.book-emoji {
  font-size: 36px;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,.2));
}
.book-title-on-spine {
  color: rgba(255,255,255,.95);
  font-size: 13px;
  font-weight: 500;
  text-align: center;
  padding: 0 10px;
  margin-top: 8px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-shadow: 0 1px 2px rgba(0,0,0,.2);
}
.book-ribbon {
  position: absolute;
  top: 8px;
  right: 8px;
  font-size: 12px;
}
.book-author-label {
  font-size: 11px;
  color: var(--text2);
  text-align: center;
  margin-top: 6px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

@media (min-width: 1600px) {
  .book { width: 170px; }
  .book-spine { height: 210px; }
  .book-emoji { font-size: 42px; }
  .book-title-on-spine { font-size: 14px; }
}
@media (max-width: 820px) {
  .book { width: 130px; }
  .book-spine { height: 160px; }
  .book-emoji { font-size: 28px; }
}
@media (max-width: 600px) {
  .book { width: calc(50% - 8px); }
  .book-spine { height: 170px; }
}
@media (max-width: 380px) {
  .book { width: calc(50% - 8px); }
  .book-spine { height: 130px; }
}
</style>
