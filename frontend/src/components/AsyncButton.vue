<script setup>
import { LoaderCircle } from '@lucide/vue'

defineProps({
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  type: { type: String, default: 'button' },
  loadingText: { type: String, default: 'Memproses…' },
})
</script>

<template>
  <button :type="type" :disabled="disabled || loading" :aria-busy="loading" :class="loading ? 'cursor-wait' : 'disabled:cursor-not-allowed'" class="inline-flex items-center justify-center gap-2 disabled:opacity-60">
    <template v-if="loading"><LoaderCircle :size="16" class="animate-spin" aria-hidden="true" /><span>{{ loadingText }}</span></template>
    <slot v-else />
  </button>
</template>
