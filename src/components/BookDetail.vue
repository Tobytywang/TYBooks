<script setup lang="ts">
import type { Book } from '../types/book'
import { onMounted, onUnmounted } from 'vue'

const props = defineProps<{ book: Book }>()
const emit = defineEmits<{ close: [] }>()

const statusMap: Record<string, { text: string; cls: string }> = {
  done: { text: '✅ 已读', cls: 'done' },
  reading: { text: '📖 在读', cls: 'reading' },
  wish: { text: '📌 想读', cls: 'wish' },
}

const tags = props.book.tags ? props.book.tags.split(',').map(t => t.trim()).filter(Boolean) : []

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => document.addEventListener('keydown', onKey))
onUnmounted(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="book-overlay active" @click.self="emit('close')">
    <div class="open-book">
      <div class="open-book-inner">
        <div class="book-left" :data-genre="book.genre">
          <div class="big-emoji">{{ book.emoji }}</div>
          <div class="big-title">{{ book.title }}</div>
          <div class="big-author">{{ book.author }}</div>
        </div>
        <div class="book-right">
          <div class="detail-status">
            <span class="status-badge" :class="statusMap[book.status]?.cls">
              {{ statusMap[book.status]?.text }}
            </span>
          </div>
          <div class="detail-tags">
            <span class="detail-tag primary">{{ book.genre }}</span>
            <span v-for="tag in tags" :key="tag" class="detail-tag">{{ tag }}</span>
          </div>
          <div class="detail-rating" :class="{ unrated: book.rating === 0 }">
            <template v-if="book.rating > 0">
              {{ '★'.repeat(book.rating) + '☆'.repeat(5 - book.rating) }}
            </template>
            <template v-else>尚未评分</template>
          </div>
          <div class="detail-review">
            {{ book.review || '暂无书评' }}
          </div>
          <button class="close-button" @click="emit('close')">合上书本 ✕</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.book-overlay {
  position: fixed;
  inset: 0;
  z-index: 900;
  background: rgba(10,10,20,.85);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.open-book {
  perspective: 1200px;
  max-width: 780px;
  width: 100%;
  animation: bookAppear .5s ease;
}

@keyframes bookAppear {
  from { opacity: 0; transform: scale(.8) rotateY(20deg); }
  to { opacity: 1; transform: scale(1) rotateY(0deg); }
}

.open-book-inner {
  display: flex;
  background: var(--surface);
  border-radius: var(--radius);
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0,0,0,.5);
  transform-style: preserve-3d;
}

.book-left {
  flex: 0 0 280px;
  min-height: 400px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px 20px;
  position: relative;
  background: var(--surface-light);
}
.book-left .big-emoji { font-size: 80px; margin-bottom: 16px; }
.book-left .big-title { font-size: 22px; font-weight: 700; text-align: center; margin-bottom: 4px; }
.book-left .big-author { font-size: 14px; color: var(--text2); text-align: center; }
.book-left::after {
  content: '';
  position: absolute;
  right: 0;
  top: 10%;
  height: 80%;
  width: 1px;
  background: linear-gradient(to bottom, transparent, var(--border), transparent);
}

.book-right {
  flex: 1;
  padding: 32px 28px;
  min-height: 400px;
  display: flex;
  flex-direction: column;
}

.status-badge {
  display: inline-block;
  padding: 4px 14px;
  border-radius: 100px;
  font-size: 12px;
  font-weight: 500;
}
.status-badge.done { background: rgba(16,185,129,.15); color: #10b981; }
.status-badge.reading { background: rgba(59,130,246,.15); color: #3b82f6; }
.status-badge.wish { background: rgba(245,158,11,.15); color: #f59e0b; }

.detail-tags { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 16px; }
.detail-tag {
  font-size: 12px;
  padding: 2px 12px;
  border-radius: 100px;
  background: var(--surface-light);
  color: var(--text2);
  border: 1px solid var(--border);
}
.detail-tag.primary {
  background: rgba(233,69,96,.15);
  color: var(--accent);
  border-color: transparent;
}

.detail-rating {
  font-size: 20px;
  letter-spacing: 2px;
  color: var(--gold);
  margin-bottom: 16px;
}
.detail-rating.unrated {
  color: var(--text2);
  font-size: 14px;
  letter-spacing: normal;
}

.detail-review {
  flex: 1;
  font-size: 14px;
  line-height: 1.8;
  color: var(--text2);
  overflow-y: auto;
  max-height: 200px;
}

.close-button {
  align-self: flex-end;
  margin-top: 16px;
  padding: 8px 20px;
  border: 1px solid var(--border);
  border-radius: 100px;
  background: transparent;
  color: var(--text2);
  font-size: 13px;
  cursor: pointer;
  transition: all .15s;
}
.close-button:hover {
  border-color: var(--accent);
  color: var(--accent);
}

@media (max-width: 820px) {
  .book-left { flex: 0 0 200px; }
}
@media (max-width: 600px) {
  .open-book-inner { flex-direction: column; }
  .book-left {
    flex: unset;
    padding: 24px 20px;
    min-height: unset;
  }
  .book-left::after { display: none; }
  .book-left .big-emoji { font-size: 56px; }
  .book-right { padding: 24px 20px; min-height: unset; }
}
</style>
