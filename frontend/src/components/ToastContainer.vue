<script setup>
import { CheckCircle2, CircleAlert, Info, TriangleAlert, X } from '@lucide/vue'
import { dismissToast, pauseToast, resumeToast, toasts } from '../services/toast'

const icons = { success: CheckCircle2, error: CircleAlert, warning: TriangleAlert, info: Info }
const colors = {
  success: 'border-brand-500 text-brand-600',
  error: 'border-error-200 text-error-700',
  warning: 'border-gray-400 text-gray-600',
  info: 'border-brand-400 text-brand-500',
}
</script>

<template>
  <Teleport to="body">
    <div aria-live="polite" aria-atomic="false" class="pointer-events-none fixed inset-x-4 top-4 z-[100] flex flex-col items-end gap-3 sm:left-auto sm:w-full sm:max-w-sm">
      <TransitionGroup enter-active-class="transition duration-200" enter-from-class="translate-y-2 opacity-0 sm:translate-x-4 sm:translate-y-0" leave-active-class="transition duration-150" leave-to-class="translate-x-4 opacity-0">
        <article v-for="item in toasts" :key="item.id" :role="item.type === 'error' ? 'alert' : 'status'" :class="colors[item.type]" class="pointer-events-auto relative w-full overflow-hidden rounded-xl border-l-4 bg-white p-4 shadow-theme-lg ring-1 ring-gray-900/5 dark:bg-gray-900 dark:ring-white/10" @mouseenter="pauseToast(item.id)" @mouseleave="resumeToast(item.id)">
          <div class="flex gap-3">
            <component :is="icons[item.type]" :size="21" class="mt-0.5 shrink-0" />
            <div class="min-w-0 flex-1"><p class="text-sm font-semibold text-gray-900 dark:text-white">{{ item.title }}</p><p class="mt-1 break-words text-sm leading-5 text-gray-600 dark:text-gray-300">{{ item.message }}</p><time class="mt-2 block text-xs text-gray-400">Baru saja</time><div v-if="item.actions.length" class="mt-3 flex justify-end gap-2"><button v-for="action in item.actions" :key="action.label" type="button" :class="action.style === 'danger' ? 'bg-error-700 text-white hover:opacity-90' : 'border border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'" class="rounded-lg px-3 py-1.5 text-xs font-semibold" @click="action.handler">{{ action.label }}</button></div></div>
            <button type="button" aria-label="Tutup notifikasi" class="shrink-0 text-gray-400 hover:text-gray-700 dark:hover:text-white" @click="dismissToast(item.id)"><X :size="18" /></button>
          </div>
          <div v-if="item.duration > 0" :style="{ animationDuration: `${item.duration}ms` }" class="toast-progress absolute bottom-0 left-0 h-0.5 w-full origin-left bg-current opacity-60"></div>
        </article>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
@keyframes toast-countdown { from { transform: scaleX(1); } to { transform: scaleX(0); } }
.toast-progress { animation-name: toast-countdown; animation-timing-function: linear; animation-fill-mode: forwards; }
article:hover .toast-progress { animation-play-state: paused; }
</style>
