<script setup lang="ts">
import { useBooks } from '../composables/useBooks'

const { search, statusFilter, sortBy, genres, genreFilter } = useBooks()
</script>

<template>
  <header>
    <div class="container header-inner">
      <div class="header-left">
        <h1>📚 我的藏书</h1>
        <div class="subtitle">就像站在书架前一样</div>
      </div>
      <div class="header-controls">
        <input
          v-model="search"
          type="text"
          placeholder="🔍 搜索书名、作者..."
        />
        <select v-model="genreFilter" class="filter-select">
          <option value="">全部分类</option>
          <option v-for="g in genres" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="statusFilter" class="filter-select">
          <option value="">全部状态</option>
          <option value="done">✅ 已读</option>
          <option value="reading">📖 在读</option>
          <option value="wish">📌 想读</option>
        </select>
        <select v-model="sortBy" class="filter-select">
          <option value="id">默认排序</option>
          <option value="title">按书名</option>
          <option value="rating">按评分</option>
        </select>
      </div>
    </div>
  </header>
</template>

<style scoped>
header {
  padding: 40px 0 20px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 40px;
}
.header-inner {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 12px;
}
.header-left h1 { font-size: 28px; font-weight: 700; letter-spacing: -.5px; }
.header-left .subtitle { font-size: 13px; color: var(--text2); margin-top: 2px; }
.header-controls { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.header-controls input {
  padding: 8px 14px;
  border-radius: 100px;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  width: 200px;
}
.header-controls input::placeholder { color: var(--text2); }
.header-controls input:focus { border-color: var(--accent); }
.filter-select {
  padding: 8px 12px;
  border-radius: 100px;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font-size: 13px;
  outline: none;
  cursor: pointer;
  appearance: none;
  -webkit-appearance: none;
  padding-right: 28px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%238b8fa3' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
}
.filter-select:focus { border-color: var(--accent); }

@media (max-width: 600px) {
  header { padding: 24px 0 16px; }
  .header-inner { flex-direction: column; align-items: stretch; }
  .header-controls { flex-wrap: wrap; }
  .header-controls input { width: 100%; }
  .filter-select { flex: 1; min-width: 0; }
}
</style>
