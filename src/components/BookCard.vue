<script setup lang="ts">
import type { Book } from '../types/book'

defineProps<{ book: Book }>()
const emit = defineEmits<{ click: [] }>()

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

const statusColors: Record<string, string> = {
  done: '#6a9e7a',
  reading: '#5c7a9e',
  wish: '#9e8a5c',
  tobuy: '#9e7a5a',
  reread: '#7a6a9e',
}
</script>

<template>
  <div class="book" @click="emit('click')">
    <div
      class="book-spine"
      :style="{ background: genreColors[book.genre] || 'var(--c-other)' }"
    >
      <span class="spine-top-line"></span>
      <span
        class="spine-status-bar"
        :style="{ background: statusColors[book.status] }"
      ></span>
      <span class="spine-title">{{ book.title }}</span>
      <span class="spine-author">{{ book.author }}</span>
      <span class="spine-bottom-line"></span>
    </div>
  </div>
</template>

<style scoped>
.book {
  cursor: pointer;
  position: relative;
  flex-shrink: 0;
}

.book-spine {
  width: 48px;
  height: 190px;
  border-radius: 2px 4px 4px 2px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  position: relative;
  padding: 16px 4px;
  box-shadow:
    2px 0 4px rgba(0,0,0,.3),
    4px 0 8px rgba(0,0,0,.15),
    inset -2px 0 4px rgba(0,0,0,.15);
  transition: transform .2s, box-shadow .2s, filter .2s;
}
.book:hover .book-spine {
  transform: translateY(-6px);
  filter: brightness(1.1);
  box-shadow:
    2px 0 4px rgba(0,0,0,.3),
    4px 0 8px rgba(0,0,0,.15),
    inset -2px 0 4px rgba(0,0,0,.15),
    0 6px 16px rgba(0,0,0,.4);
}
.book:active .book-spine { transform: translateY(-3px) scale(.97); }

.spine-top-line,
.spine-bottom-line {
  position: absolute;
  left: 4px;
  right: 4px;
  height: 1px;
  background: rgba(255,255,255,.15);
}
.spine-top-line { top: 10px; }
.spine-bottom-line { bottom: 16px; }

.spine-title {
  writing-mode: vertical-rl;
  font-size: 12px;
  font-weight: 500;
  color: rgba(255,255,255,.85);
  text-align: center;
  text-shadow: 0 1px 1px rgba(0,0,0,.3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-height: 120px;
  flex: 1;
  display: flex;
  align-items: center;
}

.spine-author {
  writing-mode: vertical-rl;
  font-size: 9px;
  color: rgba(255,255,255,.5);
  text-align: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-height: 60px;
  margin-top: 6px;
}

.spine-status-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  border-radius: 2px 4px 0 0;
}

@media (min-width: 1600px) {
  .book-spine { height: 210px; }
  .spine-title { font-size: 13px; max-height: 140px; }
}
@media (max-width: 820px) {
  .book-spine { height: 160px; }
  .spine-title { max-height: 100px; }
}
@media (max-width: 600px) {
  .book-spine { height: 150px; width: 42px; }
  .spine-title { font-size: 11px; max-height: 90px; }
}
</style>
