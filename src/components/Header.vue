<script setup lang="ts">
import { useBooks } from '../composables/useBooks'

const { search, statusFilter, sortBy, genres, genreFilter } = useBooks()
</script>

<template>
  <header>
    <div class="container header-inner">
      <div class="header-left">
        <h1>我的藏书</h1>
        <div class="subtitle">PRIVATE LIBRARY</div>
      </div>
      <div class="header-controls">
        <input
          v-model="search"
          type="text"
          placeholder="搜索书名或作者"
          class="ctrl-input"
          style="width: 200px"
        />
        <select v-model="genreFilter" class="ctrl-select">
          <option value="">全部分类</option>
          <option v-for="g in genres" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="statusFilter" class="ctrl-select">
          <option value="">全部状态</option>
          <option value="done">已读</option>
          <option value="reading">在读</option>
          <option value="wish">想读</option>
          <option value="tobuy">待购</option>
          <option value="reread">重读</option>
        </select>
        <select v-model="sortBy" class="ctrl-select">
          <option value="id">默认排序</option>
          <option value="title">按书名</option>
          <option value="rating">按评分</option>
        </select>
        <RouterLink to="/admin" class="ctrl-btn">管理</RouterLink>
      </div>
    </div>
  </header>
</template>

<style scoped>
header {
  padding: 40px 0 20px;
  border-bottom: 2px solid var(--wood-dark);
  margin-bottom: 40px;
}
.header-inner {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 12px;
}
.header-left h1 {
  font-size: 28px;
  font-weight: 300;
  letter-spacing: 4px;
  color: var(--text);
}
.header-left .subtitle {
  font-size: 11px;
  color: var(--wood);
  letter-spacing: 6px;
  margin-top: 4px;
  text-transform: uppercase;
}
.header-controls { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }

@media (max-width: 600px) {
  header { padding: 24px 0 16px; }
  .header-inner { flex-direction: column; align-items: stretch; }
  .header-left h1 { font-size: 22px; letter-spacing: 2px; }
  .header-controls { flex-wrap: wrap; }
  .ctrl-input { width: 100%; }
  .ctrl-select { flex: 1; min-width: 0; }
}
</style>
