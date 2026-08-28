<script setup>
import { LoaderCircle } from '@lucide/vue'
import { navigationLoading } from '../services/navigationLoading'
</script>

<template>
  <Transition enter-active-class="transition-opacity duration-150" enter-from-class="opacity-0" leave-active-class="transition-opacity duration-150" leave-to-class="opacity-0">
    <div v-if="navigationLoading" role="status" aria-live="polite" aria-label="Memuat halaman" class="fixed inset-0 z-[200] flex cursor-wait items-center justify-center bg-white/80 backdrop-blur-sm dark:bg-gray-950/80">
      <div class="flex flex-col items-center gap-3 rounded-2xl bg-white px-7 py-5 text-brand-600 shadow-theme-lg ring-1 ring-gray-900/5 dark:bg-gray-900 dark:ring-white/10">
        <LoaderCircle :size="32" class="animate-spin" aria-hidden="true" />
        <span class="text-sm font-semibold text-gray-700 dark:text-gray-200">Memuat halaman…</span>
      </div>
    </div>
  </Transition>
</template>
