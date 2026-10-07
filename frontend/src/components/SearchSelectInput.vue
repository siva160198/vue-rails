<script setup>
import { computed, inject, nextTick, onBeforeUnmount, ref, useAttrs, useId, watch } from 'vue'
import { ChevronDown, LoaderCircle } from '@lucide/vue'
import { formFieldContextKey } from './formFieldContext'
import { useClickOutside } from '../composables/useClickOutside'
import { t } from '../services/i18n'
import { toast } from '../services/toast'

defineOptions({ inheritAttrs: false })
const props = defineProps({
  options: { type: Array, default: () => [] },
  // ({ search, limit, signal }) => Promise<Array<{value,label,disabled?}>>
  loadOptions: { type: Function, default: null },
  limit: { type: Number, default: 50 },
  minSearchLength: { type: Number, default: 2 },
})
const emit = defineEmits(['change'])
const model = defineModel()
const attrs = useAttrs()
const field = inject(formFieldContextKey, null)
const root = ref(null)
const trigger = ref(null)
const input = ref(null)
const open = ref(false)
const search = ref('')
const remote = ref([])
const selected = ref(null)
const loading = ref(false)
const failed = ref(false)
const active = ref(-1)
const listId = `select-${useId()}`
const maxResults = computed(() => Math.max(1, Math.min(50, props.limit)))
const disabled = computed(() => attrs.disabled !== undefined && attrs.disabled !== false)
const choices = computed(() => (props.loadOptions ? remote.value : props.options.filter(option => String(option.label).toLocaleLowerCase().includes(search.value.toLocaleLowerCase()))).slice(0, maxResults.value))
const label = computed(() => [...props.options, ...remote.value, selected.value].find(option => option && option.value === model.value)?.label ?? model.value ?? t('select.placeholder'))
let timer
let controller
let sequence = 0

function cancelRequest() {
  clearTimeout(timer)
  sequence++
  controller?.abort()
  loading.value = false
}
function close() {
  open.value = false
  cancelRequest()
}
useClickOutside(root, close)
async function show() {
  if (disabled.value) return
  open.value = true
  search.value = ''
  active.value = -1
  queueSearch()
  await nextTick()
  input.value?.focus()
}
function queueSearch() {
  cancelRequest()
  failed.value = false
  active.value = -1
  if (!props.loadOptions || !open.value) return
  remote.value = []
  if (search.value.trim().length < props.minSearchLength) return
  loading.value = true
  const request = sequence
  timer = setTimeout(async () => {
    controller = new AbortController()
    try {
      const items = await props.loadOptions({ search: search.value.trim().slice(0, 200), limit: maxResults.value, signal: controller.signal })
      if (request === sequence && open.value) remote.value = items.slice(0, maxResults.value)
    } catch (error) {
      if (request === sequence && error.name !== 'AbortError') { failed.value = true; toast.error(error.message) }
    } finally { if (request === sequence) loading.value = false }
  }, 300)
}
watch(search, queueSearch)
watch(disabled, value => { if (value) close() })
onBeforeUnmount(cancelRequest)
function choose(option) {
  if (disabled.value || loading.value || option.disabled) return
  selected.value = option
  model.value = option.value
  emit('change', { target: { value: option.value } })
  close()
  trigger.value?.focus()
}
function keydown(event) {
  if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close(); trigger.value?.focus(); return }
  if (event.key === 'Tab') { close(); return }
  if (!['ArrowDown', 'ArrowUp', 'Enter'].includes(event.key)) return
  event.preventDefault()
  if (event.key === 'Enter') { if (choices.value[active.value]) choose(choices.value[active.value]); return }
  const direction = event.key === 'ArrowDown' ? 1 : -1
  let index = active.value < 0 && direction === -1 ? 0 : active.value
  for (let count = 0; count < choices.value.length; count++) {
    index = (index + direction + choices.value.length) % choices.value.length
    if (!choices.value[index].disabled) { active.value = index; break }
  }
  nextTick(() => root.value?.querySelector(`#${listId}-${active.value}`)?.scrollIntoView?.({ block: 'nearest' }))
}
</script>
<template>
  <div ref="root" class="relative w-full" @keydown="open && keydown($event)">
    <button ref="trigger" v-bind="attrs" :id="attrs.id || field?.controlId.value" type="button" :disabled="disabled" :aria-describedby="attrs['aria-describedby'] || field?.describedBy.value" :aria-invalid="attrs['aria-invalid'] ?? field?.invalid.value" aria-haspopup="listbox" :aria-expanded="open" :aria-controls="open ? listId : undefined" class="flex w-full items-center justify-between gap-3 rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-left text-sm text-gray-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-4 focus:ring-brand-100 aria-[invalid=true]:border-error-500 disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900 dark:text-white" @click="open ? close() : show()" @keydown.down.prevent="!open && show()">
      <span class="truncate">{{ label || t('select.placeholder') }}</span><ChevronDown :size="16" class="shrink-0 text-gray-500" />
    </button>
    <div v-if="open" class="absolute left-0 right-0 z-30 mt-1 rounded-xl border border-gray-200 bg-white p-2 shadow-theme-lg dark:border-gray-700 dark:bg-gray-900">
      <input ref="input" v-model="search" role="combobox" :aria-label="t('select.search')" aria-autocomplete="list" aria-expanded="true" :aria-controls="listId" :aria-activedescendant="active >= 0 ? `${listId}-${active}` : undefined" maxlength="200" :placeholder="t('select.search')" class="w-full rounded-lg border border-gray-300 bg-transparent px-3 py-2 text-sm dark:border-gray-700 dark:text-white" />
      <div :id="listId" role="listbox" :aria-label="attrs['aria-label'] || label || t('select.placeholder')" :aria-busy="loading" class="mt-2 max-h-56 overflow-y-auto">
        <div v-for="(option, index) in choices" :id="`${listId}-${index}`" :key="option.value" role="option" :aria-selected="model === option.value" :aria-disabled="Boolean(option.disabled)" class="cursor-pointer rounded-lg px-3 py-2 text-sm text-gray-700 dark:text-gray-200" :class="[index === active || model === option.value ? 'bg-brand-50 text-brand-600 dark:bg-brand-500/10' : 'hover:bg-gray-50 dark:hover:bg-gray-800', option.disabled && 'cursor-not-allowed opacity-50']" @mousedown.prevent="choose(option)">{{ option.label }}</div>
      </div>
      <div v-if="loading" role="status" class="flex items-center justify-center gap-2 p-3 text-sm text-gray-500"><LoaderCircle :size="16" class="animate-spin" />{{ t('common.loading_data') }}</div>
      <button v-else-if="failed" type="button" class="w-full p-3 text-sm text-brand-500" @click="queueSearch">{{ t('common.retry') }}</button>
      <p v-else-if="!choices.length" role="status" class="p-3 text-sm text-gray-500">{{ t(loadOptions && search.trim().length < minSearchLength ? 'select.type_more' : 'select.empty', { count: minSearchLength }) }}</p>
    </div>
  </div>
</template>
