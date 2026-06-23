<script setup lang="ts">
import { computed } from 'vue'
import type { Book, BookCreate } from '../types/book'

const props = defineProps<{
  book?: Book
}>()

const emit = defineEmits<{
  submit: [data: BookCreate]
  cancel: []
}>()

const genres = ['小说', '技术', '历史', '哲学', '科学', '商业', '非虚构', '文学', '艺术', '传记', '其他']
const statuses: { value: string; label: string }[] = [
  { value: 'wish', label: '想读' },
  { value: 'tobuy', label: '待购' },
  { value: 'reading', label: '在读' },
  { value: 'done', label: '已读' },
  { value: 'reread', label: '重读' },
]

const form = defineModel<BookCreate>('form', {
  required: true,
})

function setRating(n: number) {
  form.value.rating = n
}

const ratingValue = computed(() => form.value.rating ?? 0)
</script>

<template>
  <form @submit.prevent="emit('submit', form)" class="book-form">
    <div class="form-grid">
      <div class="field">
        <label>Emoji</label>
        <input v-model="form.emoji" type="text" maxlength="4" class="input-emoji" />
      </div>
      <div class="field span-3">
        <label>书名 <span class="required">*</span></label>
        <input v-model="form.title" type="text" required />
      </div>
      <div class="field span-2">
        <label>作者 <span class="required">*</span></label>
        <input v-model="form.author" type="text" required />
      </div>
      <div class="field">
        <label>分类 <span class="required">*</span></label>
        <select v-model="form.genre" required>
          <option value="" disabled>选择分类</option>
          <option v-for="g in genres" :key="g" :value="g">{{ g }}</option>
        </select>
      </div>
      <div class="field">
        <label>状态</label>
        <select v-model="form.status">
          <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
      </div>
      <div class="field">
        <label>评分</label>
        <div class="rating-input">
          <span
            v-for="n in 5"
            :key="n"
            class="star"
            :class="{ active: n <= ratingValue }"
            @click="setRating(n)"
          >★</span>
          <span v-if="ratingValue > 0" class="clear-rating" @click="setRating(0)">清除</span>
        </div>
      </div>
      <div class="field span-4">
        <label>书评</label>
        <textarea v-model="form.review" rows="4"></textarea>
      </div>
      <div class="field span-4">
        <label>标签（逗号分隔）</label>
        <input v-model="form.tags" type="text" placeholder="如：文学, 非虚构" />
      </div>
    </div>
    <div class="form-actions">
      <button type="button" @click="emit('cancel')" class="btn-cancel">取消</button>
      <button type="submit" class="btn-submit">{{ book ? '保存修改' : '添加书籍' }}</button>
    </div>
  </form>
</template>

<style scoped>
.book-form {
  width: 100%;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.field {
  display: flex;
  flex-direction: column;
}

.field.span-2 { grid-column: span 2; }
.field.span-3 { grid-column: span 3; }
.field.span-4 { grid-column: span 4; }

.field label {
  font-size: 11px;
  color: var(--text2);
  margin-bottom: 4px;
  letter-spacing: 1px;
}

.required {
  color: var(--danger);
}

.field input,
.field textarea {
  padding: 8px 14px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  transition: border-color .15s;
  font-family: inherit;
  line-height: 1.4;
}

.field select {
  padding: 8px 28px 8px 12px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  cursor: pointer;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%238a8578' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  transition: border-color .15s;
  line-height: 1.4;
}

.field input:focus,
.field select:focus,
.field textarea:focus {
  border-color: var(--accent);
}

.input-emoji {
  text-align: center;
  font-size: 18px;
}

.field select {
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%238a8578' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  padding-right: 28px;
  cursor: pointer;
}

.field textarea {
  resize: vertical;
  min-height: 72px;
  line-height: 1.6;
}

.rating-input {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 0;
}

.star {
  font-size: 18px;
  color: var(--border);
  cursor: pointer;
  transition: color .15s;
}

.star.active {
  color: var(--accent);
}

.star:hover {
  color: var(--accent);
}

.clear-rating {
  font-size: 11px;
  color: var(--text2);
  cursor: pointer;
  margin-left: 8px;
  transition: color .15s;
}

.clear-rating:hover {
  color: var(--danger);
}

.form-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.btn-cancel,
.btn-submit {
  padding: 8px 20px;
  border-radius: var(--radius);
  font-size: 13px;
  cursor: pointer;
  border: none;
  transition: opacity .15s;
}

.btn-cancel {
  background: var(--surface-light);
  color: var(--text2);
}

.btn-submit {
  background: var(--accent);
  color: #fff;
  letter-spacing: 1px;
}

.btn-cancel:hover {
  opacity: .8;
}

.btn-submit:hover {
  opacity: .9;
}

@media (max-width: 820px) {
  .form-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .field.span-3 { grid-column: span 2; }
  .field.span-4 { grid-column: span 2; }
}

@media (max-width: 600px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
  .field.span-2,
  .field.span-3,
  .field.span-4 { grid-column: span 1; }
}
</style>
