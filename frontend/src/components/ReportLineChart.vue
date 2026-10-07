<script setup>
import { computed, ref } from 'vue'
import { LoaderCircle } from '@lucide/vue'
import AsyncButton from './AsyncButton.vue'
import { locale, t } from '../services/i18n'

const props = defineProps({ current: { type: Array, default: () => [] }, previous: { type: Array, default: () => [] }, loading: Boolean, error: Boolean, title: { type: String, required: true } })
defineEmits(['retry'])
const active = ref(null)
const max = computed(() => Math.max(1, ...props.current.map(point => point.value), ...props.previous.map(point => point.value)))
const x = index => 30 + index / Math.max(1, props.current.length - 1) * 540
const y = value => 210 - value / max.value * 180
const path = points => points.map((point, index) => `${index ? 'L' : 'M'} ${x(index)} ${y(point.value)}`).join(' ')
const empty = computed(() => !props.current.some(point => point.value !== 0) && !props.previous.some(point => point.value !== 0))
const number = value => new Intl.NumberFormat(locale.value).format(value || 0)
</script>
<template>
  <div :aria-busy="loading" class="relative mt-4">
    <div v-if="loading" role="status" class="flex h-64 items-center justify-center gap-3 text-gray-500"><LoaderCircle :size="24" class="animate-spin text-brand-500" />{{ t('common.loading_data') }}</div>
    <div v-else-if="error" class="flex h-64 flex-col items-center justify-center gap-3 text-sm text-gray-500"><p>{{ t('report.failed') }}</p><AsyncButton class="rounded-lg border border-gray-200 px-4 py-2" @click="$emit('retry')">{{ t('common.retry') }}</AsyncButton></div>
    <p v-else-if="empty" role="status" class="flex h-64 items-center justify-center text-sm text-gray-500">{{ t('report.empty') }}</p>
    <template v-else>
      <svg viewBox="0 0 600 240" role="group" :aria-label="title" class="h-auto w-full" preserveAspectRatio="xMidYMid meet">
        <path d="M30 20 V210 H570" fill="none" stroke="currentColor" class="text-gray-200 dark:text-gray-700" />
        <path :d="path(previous)" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="5 5" class="text-gray-400" />
        <path :d="path(current)" fill="none" stroke="currentColor" stroke-width="3" class="text-brand-500" />
        <circle v-for="(point, index) in current" :key="point.date" :cx="x(index)" :cy="y(point.value)" r="5" tabindex="0" role="button" :aria-label="`${point.date}: ${number(point.value)}; ${t('report.previous')}: ${number(previous[index]?.value)}`" class="cursor-pointer fill-brand-500 focus:stroke-gray-900" @mouseenter="active = index" @mouseleave="active = null" @focus="active = index" @blur="active = null" @click="active = active === index ? null : index" @keydown.enter.prevent="active = index" @keydown.space.prevent="active = index" />
      </svg>
      <div v-if="active !== null && current[active]" role="status" class="rounded-lg border border-gray-200 bg-white p-3 text-xs text-gray-700 shadow-theme-sm dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200">{{ current[active].date }}: {{ number(current[active].value) }} · {{ t('report.previous') }} {{ previous[active]?.date }}: {{ number(previous[active]?.value) }}</div>
      <div class="flex justify-between text-xs text-gray-500"><span>{{ current[0]?.date }}</span><span>{{ current.at(-1)?.date }}</span></div>
      <div class="mt-3 flex gap-4 text-xs text-gray-500"><span class="text-brand-500">{{ t('report.current') }}</span><span>{{ t('report.previous') }}</span></div>
    </template>
  </div>
</template>
