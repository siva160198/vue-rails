<script setup>
import { computed, ref } from 'vue'
import { ChevronRight, X } from '@lucide/vue'
import { t } from '../services/i18n'
const props = defineProps({ permissions: { type: Array, default: () => [] }, disabled: { type: Boolean, default: false } })
const selected = defineModel({ type: Array, default: () => [] })
const modalOpen = ref(false)
const preview = computed(() => props.permissions.slice(0, 5))
const remaining = computed(() => Math.max(0, props.permissions.length - 5))
</script>
<template>
  <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
    <label v-for="permission in preview" :key="permission.key" class="flex cursor-pointer items-start gap-2 rounded-lg border border-gray-200 p-2.5 text-xs dark:border-gray-700"><input v-model="selected" type="checkbox" :value="permission.key" :disabled="disabled" class="mt-0.5" /><span><strong class="block text-gray-800 dark:text-white">{{ permission.name }}</strong><small class="mt-0.5 block text-gray-500">{{ permission.description }}</small></span></label>
    <button v-if="remaining" type="button" :disabled="disabled" class="flex min-h-16 items-center justify-between rounded-lg border border-dashed border-gray-300 p-3 text-left text-sm font-semibold text-brand-600 hover:border-brand-400 hover:bg-brand-50 disabled:opacity-50 dark:border-gray-700 dark:hover:bg-brand-500/10" @click="modalOpen = true">{{ t('roles.more', { count: remaining }) }}<ChevronRight :size="18" /></button>
  </div>
  <Teleport to="body"><div v-if="modalOpen" class="fixed inset-0 z-[250] flex items-center justify-center bg-gray-950/50 p-4 backdrop-blur-sm" @click.self="modalOpen = false"><section role="dialog" aria-modal="true" :aria-label="t('roles.permission_modal_title')" class="max-h-[85vh] w-full max-w-3xl overflow-hidden rounded-2xl bg-white shadow-theme-lg dark:bg-gray-900"><header class="flex items-start justify-between border-b border-gray-200 p-5 dark:border-gray-800"><div><h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t('roles.permission_modal_title') }}</h2><p class="mt-1 text-sm text-gray-500">{{ t('roles.permission_modal_hint') }}</p></div><button type="button" :aria-label="t('common.close')" class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800" @click="modalOpen = false"><X :size="20" /></button></header><div class="grid max-h-[60vh] gap-3 overflow-y-auto p-5 sm:grid-cols-2"><label v-for="permission in permissions" :key="permission.key" class="flex cursor-pointer items-start gap-3 rounded-xl border border-gray-200 p-3 dark:border-gray-700"><input v-model="selected" type="checkbox" :value="permission.key" :disabled="disabled" class="mt-1" /><span><strong class="block text-sm text-gray-900 dark:text-white">{{ permission.name }}</strong><small class="text-gray-500">{{ permission.description }}</small></span></label></div><footer class="flex justify-end border-t border-gray-200 p-4 dark:border-gray-800"><button type="button" class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600" @click="modalOpen = false">{{ t('common.done') }}</button></footer></section></div></Teleport>
</template>
