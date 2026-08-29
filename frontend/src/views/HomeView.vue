<script setup>
import { onMounted, ref } from 'vue'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import { t } from '../services/i18n'

const api = ref({ state: 'loading', data: null, error: null })
const stack = ['Vue 3', 'Vite', 'Ruby on Rails', 'PostgreSQL', 'JSON / REST', 'Tailwind CSS']

onMounted(async () => {
  try {
    api.value = { state: 'ready', data: await apiFetch('/api/v1/status'), error: null }
  } catch (error) {
    api.value = { state: 'error', data: null, error: error.message }
    toast.error(`${t('home.disconnected')}: ${error.message}`)
  }
})
</script>

<template>
  <main class="px-6 py-16"><section class="mx-auto max-w-5xl">
    <div class="mb-12 max-w-2xl">
      <p class="mb-3 text-sm font-semibold uppercase tracking-[0.25em] text-brand-600">Vue Rails</p>
      <h1 class="text-4xl font-bold tracking-tight sm:text-6xl">{{ t('home.title') }}</h1>
      <p class="mt-5 text-lg leading-8 text-slate-600">{{ t('home.subtitle') }}</p>
    </div>
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <article v-for="item in stack" :key="item" class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <div class="mb-4 h-2 w-12 rounded-full bg-brand-500"></div><h2 class="font-semibold">{{ item }}</h2>
      </article>
    </div>
    <div class="mt-8 flex items-center gap-3 rounded-2xl border bg-white p-5 shadow-sm">
      <span class="h-3 w-3 rounded-full" :class="api.state === 'ready' ? 'bg-brand-500' : api.state === 'error' ? 'bg-error-700' : 'animate-pulse bg-gray-400'"></span>
      <p v-if="api.state === 'loading'">{{ t('home.connecting') }}</p>
      <p v-else-if="api.state === 'ready'">{{ t('home.connected') }} — {{ api.data.database.adapter }} / {{ api.data.database.name }}</p>
      <p v-else class="text-error-700">{{ t('home.disconnected') }}: {{ api.error }}</p>
    </div>
  </section></main>
</template>
