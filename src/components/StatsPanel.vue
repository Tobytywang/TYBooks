<script setup lang="ts">
import { useBooks } from '../composables/useBooks'

const { stats } = useBooks()
</script>

<template>
  <section class="stats">
    <div class="stats-left">
      <div class="stat-item total">
        <span class="num">{{ stats.total }}</span>
        <span class="label">总藏书</span>
      </div>
      <div class="stat-item reading">
        <span class="num">{{ stats.reading }}</span>
        <span class="label">在读</span>
      </div>
      <div class="stat-item done">
        <span class="num">{{ stats.done }}</span>
        <span class="label">已读</span>
      </div>
      <div class="stat-item wish">
        <span class="num">{{ stats.wish }}</span>
        <span class="label">想读</span>
      </div>
    </div>
    <div class="stats-right">
      <div class="stacked-bar">
        <div
          v-for="g in stats.byGenre"
          :key="g.genre"
          class="stacked-segment"
          :data-genre="g.genre"
          :style="{ width: stats.total ? (g.count / stats.total * 100) + '%' : '0%' }"
        ></div>
      </div>
      <div class="legend">
        <span v-for="g in stats.byGenre" :key="g.genre" class="legend-item">
          <span class="legend-dot" :data-genre="g.genre"></span>
          <span class="legend-text">{{ g.genre }} {{ g.count }}</span>
        </span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.stats {
  display: flex;
  gap: 32px;
  margin-bottom: 40px;
  align-items: center;
}
.stats-left {
  display: flex;
  gap: 20px;
  flex-shrink: 0;
}
.stat-item {
  text-align: center;
  padding: 4px 0;
}
.stat-item .num { display: block; font-size: 32px; font-weight: 700; color: var(--text); }
.stat-item .label {
  font-size: 11px;
  color: var(--text2);
  letter-spacing: 1px;
  display: block;
  margin-top: 2px;
}
.stat-item { border-top: 2px solid var(--border); padding-top: 8px; }
.stat-item.total { border-top-color: var(--text); }
.stat-item.reading { border-top-color: var(--c-tech); }
.stat-item.done { border-top-color: #6a9e7a; }
.stat-item.wish { border-top-color: var(--c-nonfic); }

.stats-right {
  flex: 1;
  min-width: 0;
}
.stacked-bar {
  display: flex;
  height: 6px;
  border-radius: 3px;
  overflow: hidden;
  background: var(--surface);
}
.stacked-segment {
  min-width: 2px;
  transition: width .4s ease;
}
.stacked-segment[data-genre="小说"] { background: var(--c-novel); }
.stacked-segment[data-genre="技术"] { background: var(--c-tech); }
.stacked-segment[data-genre="历史"] { background: var(--c-history); }
.stacked-segment[data-genre="哲学"] { background: var(--c-philosophy); }
.stacked-segment[data-genre="科学"] { background: var(--c-science); }
.stacked-segment[data-genre="商业"] { background: var(--c-business); }
.stacked-segment[data-genre="非虚构"] { background: var(--c-nonfic); }
.stacked-segment[data-genre="文学"] { background: var(--c-literature); }
.stacked-segment[data-genre="艺术"] { background: var(--c-art); }

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 16px;
  margin-top: 8px;
}
.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}
.legend-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}
.legend-dot[data-genre="小说"] { background: var(--c-novel); }
.legend-dot[data-genre="技术"] { background: var(--c-tech); }
.legend-dot[data-genre="历史"] { background: var(--c-history); }
.legend-dot[data-genre="哲学"] { background: var(--c-philosophy); }
.legend-dot[data-genre="科学"] { background: var(--c-science); }
.legend-dot[data-genre="商业"] { background: var(--c-business); }
.legend-dot[data-genre="非虚构"] { background: var(--c-nonfic); }
.legend-dot[data-genre="文学"] { background: var(--c-literature); }
.legend-dot[data-genre="艺术"] { background: var(--c-art); }
.legend-text { font-size: 11px; color: var(--text2); }

@media (max-width: 600px) {
  .stats { flex-direction: column; gap: 20px; align-items: stretch; }
  .stats-left { justify-content: center; gap: 16px; }
  .stat-item .num { font-size: 24px; }
}
</style>
