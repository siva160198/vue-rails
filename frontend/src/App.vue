<script setup>
import { useRoute } from 'vue-router'
import AppErrorView from './views/AppErrorView.vue'
import { appError } from './services/errorState'

const route = useRoute()
</script>

<template>
  <div class="min-h-screen bg-slate-50 text-slate-900">
    <header v-if="route.meta.layout !== 'admin'" class="border-b border-slate-200 bg-white">
      <nav class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <RouterLink to="/" class="text-xl font-bold tracking-tight">Tourplan</RouterLink>
        <div class="flex items-center gap-5 text-sm font-medium">
          <RouterLink to="/" class="hover:text-emerald-600">Home</RouterLink>
          <RouterLink to="/register" class="hover:text-emerald-600">Daftar</RouterLink>
          <RouterLink to="/admin" class="hover:text-emerald-600">Admin</RouterLink>
        </div>
      </nav>
    </header>
    <AppErrorView v-if="appError" />
    <RouterView v-else />
  </div>
</template>
