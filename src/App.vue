<script setup lang="ts">
</script>

<template>
  <RouterView />
</template>

<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg: #1c1f26;
  --surface: #252830;
  --surface-light: #2e3139;
  --paper: #f5f0e8;
  --paper-text: #3a3530;
  --wood: #8b7355;
  --wood-dark: #5c4a32;
  --text: #d4d0c8;
  --text2: #8a8578;
  --border: #3a3d45;
  --accent: #c4956a;
  --gold: #c4956a;
  --shadow: 0 2px 8px rgba(0,0,0,.3);
  --radius: 4px;
  --c-novel: #a85c5c;
  --c-nonfic: #9e8a5c;
  --c-history: #7a6a8e;
  --c-science: #5a8a8e;
  --c-tech: #5c7a9e;
  --c-philosophy: #8a6a7a;
  --c-art: #8e5a6a;
  --c-business: #5a8a7a;
  --c-literature: #9e7a5c;
  --c-biography: #6a6a8e;
  --c-other: #6b6b6b;
  --serif: "Noto Serif SC", "STSong", "Songti SC", Georgia, "Times New Roman", serif;
  --danger: #c45a5a;
  --success: #6a9e7a;
}

body {
  font-family: "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", -apple-system, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
}

.container { max-width: 1600px; margin: 0 auto; padding: 0 32px; }

.book-overlay-enter-active,
.book-overlay-leave-active {
  transition: opacity .3s ease;
}
.book-overlay-enter-active .book-overlay,
.book-overlay-leave-active .book-overlay {
  transition: opacity .3s ease;
}
.book-overlay-enter-from,
.book-overlay-leave-to {
  opacity: 0;
}

.book-overlay-enter-active .book-left {
  animation: pageLeftOpen .4s ease forwards;
}
.book-overlay-enter-active .book-right {
  animation: pageRightOpen .4s ease .1s forwards;
  opacity: 0;
}
.book-overlay-leave-active .book-left {
  animation: pageLeftClose .3s ease forwards;
}
.book-overlay-leave-active .book-right {
  animation: pageRightClose .3s ease forwards;
}

@keyframes pageLeftOpen {
  from { transform: rotateY(-90deg); }
  to { transform: rotateY(0deg); }
}
@keyframes pageRightOpen {
  from { transform: rotateY(90deg); opacity: 0; }
  to { transform: rotateY(0deg); opacity: 1; }
}
@keyframes pageLeftClose {
  from { transform: rotateY(0deg); }
  to { transform: rotateY(-90deg); }
}
@keyframes pageRightClose {
  from { transform: rotateY(0deg); }
  to { transform: rotateY(90deg); }
}
</style>
