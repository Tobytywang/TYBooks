<script setup lang="ts">
import type { Book } from '../types/book'
import { onMounted, onUnmounted } from 'vue'

const props = defineProps<{ book: Book }>()
const emit = defineEmits<{ close: [] }>()

const statusMap: Record<string, { text: string; cls: string }> = {
  done: { text: '已读', cls: 'done' },
  reading: { text: '在读', cls: 'reading' },
  wish: { text: '想读', cls: 'wish' },
}

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
        <div
          class="book-left"
          :style="{ background: genreColors[book.genre] || 'var(--c-other)' }"
        >
          <span class="cover-top-line"></span>
          <span class="cover-bottom-line"></span>
          <div class="cover-title">{{ book.title }}</div>
          <div class="cover-author">{{ book.author }}</div>
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
          <button class="close-button" @click="emit('close')">关闭</button>
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
  background: rgba(0,0,0,.7);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.open-book {
  max-width: 780px;
  width: 100%;
  animation: bookAppear .3s ease;
}

@keyframes bookAppear {
  from { opacity: 0; transform: scale(.95); }
  to { opacity: 1; transform: scale(1); }
}

.open-book-inner {
  display: flex;
  background: var(--paper);
  border-radius: var(--radius);
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0,0,0,.5);
}

.book-left {
  flex: 0 0 260px;
  min-height: 400px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 24px;
  position: relative;
  box-shadow: inset -6px 0 12px rgba(0,0,0,.2);
}

.cover-top-line,
.cover-bottom-line {
  position: absolute;
  left: 16px;
  right: 16px;
  height: 1px;
  background: rgba(255,255,255,.12);
}
.cover-top-line { top: 20px; }
.cover-bottom-line { bottom: 20px; }

.cover-title {
  font-family: var(--serif);
  font-size: 24px;
  font-weight: 700;
  text-align: center;
  color: rgba(255,255,255,.9);
  text-shadow: 0 1px 2px rgba(0,0,0,.3);
  margin-bottom: 8px;
  line-height: 1.4;
}
.cover-author {
  font-size: 13px;
  color: rgba(255,255,255,.55);
  text-align: center;
}

.book-right {
  flex: 1;
  padding: 32px 28px;
  min-height: 400px;
  display: flex;
  flex-direction: column;
  background: var(--paper);
  color: var(--paper-text);
  box-shadow: inset 4px 0 10px rgba(0,0,0,.06);
}

.status-badge {
  display: inline-block;
  padding: 3px 12px;
  border-radius: var(--radius);
  font-size: 12px;
  font-weight: 500;
}
.status-badge.done { background: rgba(106,158,122,.15); color: #5a8a6a; }
.status-badge.reading { background: rgba(92,122,158,.15); color: #5c7a9e; }
.status-badge.wish { background: rgba(158,138,92,.15); color: #8a7a5c; }

.detail-tags { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 16px; }
.detail-tag {
  font-size: 12px;
  padding: 2px 10px;
  border-radius: var(--radius);
  background: rgba(0,0,0,.06);
  color: var(--paper-text);
  opacity: .7;
}
.detail-tag.primary {
  background: rgba(196,149,106,.2);
  color: #8a6a3a;
  opacity: 1;
}

.detail-rating {
  font-size: 18px;
  letter-spacing: 2px;
  color: var(--accent);
  margin-bottom: 16px;
}
.detail-rating.unrated {
  color: var(--paper-text);
  font-size: 13px;
  letter-spacing: normal;
  opacity: .4;
}

.detail-review {
  flex: 1;
  font-family: var(--serif);
  font-size: 14px;
  line-height: 2;
  color: var(--paper-text);
  opacity: .8;
  overflow-y: auto;
  max-height: 200px;
}

.close-button {
  align-self: flex-end;
  margin-top: 16px;
  padding: 6px 16px;
  border: 1px solid rgba(0,0,0,.15);
  border-radius: var(--radius);
  background: transparent;
  color: var(--paper-text);
  opacity: .5;
  font-size: 13px;
  cursor: pointer;
  transition: all .15s;
}
.close-button:hover {
  opacity: 1;
  border-color: rgba(0,0,0,.3);
}

@media (max-width: 820px) {
  .book-left { flex: 0 0 200px; }
}
@media (max-width: 600px) {
  .open-book-inner { flex-direction: column; }
  .book-left {
    flex: unset;
    padding: 28px 20px;
    min-height: unset;
    box-shadow: inset 0 -4px 8px rgba(0,0,0,.1);
  }
  .cover-top-line { display: none; }
  .cover-bottom-line { display: none; }
  .cover-title { font-size: 20px; }
  .book-right { padding: 24px 20px; min-height: unset; }
}
</style>
