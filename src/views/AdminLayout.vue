<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const route = useRoute()
const { logout } = useAuth()

function handleLogout() {
  logout()
  router.push('/admin')
}
</script>

<template>
  <div class="admin-layout">
    <header class="admin-header">
      <div class="admin-header-left">
        <h1>藏书管理</h1>
        <span class="admin-badge">ADMIN</span>
      </div>
      <nav class="admin-nav">
        <RouterLink to="/admin/dashboard" class="ctrl-btn" :class="{ active: route.path === '/admin/dashboard' || route.path.startsWith('/admin/books') }">书籍</RouterLink>
        <RouterLink to="/admin/genres" class="ctrl-btn" :class="{ active: route.path === '/admin/genres' }">分类</RouterLink>
        <RouterLink to="/" class="ctrl-btn">返回书架</RouterLink>
        <button @click="handleLogout" class="ctrl-btn logout">退出登录</button>
      </nav>
    </header>

    <RouterView />
  </div>
</template>

<style scoped>
.admin-layout {
  min-height: 100vh;
}

.admin-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 32px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}

.admin-header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.admin-header-left h1 {
  font-size: 20px;
  font-weight: 400;
  letter-spacing: 3px;
  color: var(--text);
}

.admin-badge {
  font-size: 10px;
  letter-spacing: 3px;
  color: var(--accent);
  border: 1px solid var(--accent);
  padding: 2px 8px;
  border-radius: 2px;
}

.admin-nav {
  display: flex;
  gap: 10px;
  align-items: center;
}

.ctrl-btn.logout:hover {
  color: var(--danger);
  border-color: var(--danger);
}

.ctrl-btn.active {
  border-color: var(--accent);
  color: var(--accent);
  background: rgba(196,149,106,.08);
}

@media (max-width: 600px) {
  .admin-header {
    padding: 16px 20px;
    flex-direction: column;
    gap: 12px;
  }
}
</style>
