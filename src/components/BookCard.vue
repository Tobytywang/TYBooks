<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import type { Book } from '../types/book'

const props = defineProps<{ book: Book }>()
const emit = defineEmits<{ click: [] }>()

const titleRef = ref<HTMLElement | null>(null)
const spineRef = ref<HTMLElement | null>(null)
const showAuthor = ref(true)

function getThreshold() {
  const w = window.innerWidth
  if (w >= 1600) return 130
  if (w >= 820) return 90
  if (w >= 600) return 65
  return 55
}

function getAuthorTop() {
  const w = window.innerWidth
  if (w >= 1600) return 140
  if (w >= 820) return 110
  if (w >= 600) return 90
  return 78
}

const authorTop = ref(getAuthorTop())

function measure() {
  authorTop.value = getAuthorTop()
  if (titleRef.value) {
    const el = titleRef.value
    const orig = el.style.maxHeight
    el.style.maxHeight = 'none'
    const fullHeight = el.scrollHeight
    el.style.maxHeight = orig
    showAuthor.value = fullHeight <= getThreshold()
  }
}

onMounted(() => {
  measure()
  window.addEventListener('resize', measure)
})

onUnmounted(() => {
  window.removeEventListener('resize', measure)
})

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
      <div class="spine-text">
        <span ref="titleRef" class="spine-title" :class="{ 'no-author': !showAuthor }">{{ book.title }}</span>
        <span v-if="showAuthor" class="spine-author" :style="{ top: authorTop + 'px' }">{{ book.author }}</span>
      </div>
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
  overflow: hidden;
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

.spine-text {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 6px;
  overflow: hidden;
}

.spine-title {
  writing-mode: vertical-rl;
  font-size: 12px;
  font-weight: 500;
  color: rgba(255,255,255,.85);
  text-shadow: 0 1px 1px rgba(0,0,0,.3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-height: 120px;
  line-height: 1;
}

.spine-title.no-author {
  max-height: none;
}

.spine-author {
  writing-mode: vertical-rl;
  font-size: 9px;
  color: rgba(255,255,255,.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-height: 60px;
  line-height: 1;
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
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
  .spine-author { max-height: 40px; }
}
@media (max-width: 600px) {
  .book-spine { height: 150px; width: 42px; }
  .spine-title { font-size: 11px; max-height: 90px; }
  .spine-author { max-height: 40px; }
}
</style>
