<script setup>
import { t } from '../services/i18n'
defineProps({
  code: { type: String, required: true },
  title: { type: String, required: true },
  message: { type: String, required: true },
  showRetry: { type: Boolean, default: false },
})

defineEmits(['retry'])
</script>

<template>
  <main class="flex min-h-[calc(100vh-73px)] items-center justify-center px-6 py-16">
    <div class="w-full max-w-xl text-center">
      <p class="text-8xl font-bold tracking-tight text-brand-500 sm:text-9xl">{{ code }}</p>
      <h1 class="mt-6 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">{{ title }}</h1>
      <p class="mx-auto mt-4 max-w-md text-base leading-7 text-slate-600">{{ message }}</p>
      <div class="mt-8 flex flex-wrap justify-center gap-3">
        <button
          v-if="showRetry"
          type="button"
          class="rounded-xl bg-brand-500 px-5 py-3 text-sm font-semibold text-white hover:bg-brand-600"
          @click="$emit('retry')"
        >
          {{ t('common.retry') }}
        </button>
        <RouterLink to="/" class="rounded-xl border border-slate-300 bg-white px-5 py-3 text-sm font-semibold text-slate-700 hover:bg-slate-50">
          {{ t('common.back_home') }}
        </RouterLink>
      </div>
    </div>
  </main>
</template>
