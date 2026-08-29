<script setup>
import { inject, useAttrs } from 'vue'
import { ChevronDown } from '@lucide/vue'
import { formFieldContextKey } from './formFieldContext'

defineOptions({ inheritAttrs: false })
const attrs = useAttrs()
const field = inject(formFieldContextKey, null)
const model = defineModel()

function updateValue(event) {
  model.value = typeof model.value === 'number' ? Number(event.target.value) : event.target.value
}
</script>

<template>
  <span class="relative inline-flex min-w-0">
    <select v-bind="attrs" :id="attrs.id || field?.controlId.value" :aria-describedby="attrs['aria-describedby'] || field?.describedBy.value" :aria-invalid="attrs['aria-invalid'] ?? field?.invalid.value" :value="model" class="w-full appearance-none rounded-lg border border-gray-300 bg-white py-2 pl-3 pr-9 text-sm text-gray-900 shadow-sm transition-colors hover:border-gray-400 focus:border-brand-500 focus:ring-4 focus:ring-brand-100 focus:outline-none disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white dark:hover:border-gray-600 dark:focus:border-brand-400 dark:focus:ring-brand-500/15" @change="updateValue"><slot /></select>
    <ChevronDown :size="16" class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-gray-500" aria-hidden="true" />
  </span>
</template>
