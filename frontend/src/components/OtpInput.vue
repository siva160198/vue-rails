<script setup>
import { inject, nextTick, ref, useAttrs } from 'vue'
import { formFieldContextKey } from './formFieldContext'
import TextInput from './TextInput.vue'
import { LoaderCircle } from '@lucide/vue'
import { t } from '../services/i18n'

defineOptions({ inheritAttrs: false })
const props = defineProps({ allowRecovery: { type: Boolean, default: false }, disabled: { type: Boolean, default: false } })
const model = defineModel({ type: String, default: '' })
const emit = defineEmits(['input', 'recovery-change'])
const attrs = useAttrs()
const field = inject(formFieldContextKey, null)
const recovery = ref(false)
const controls = ref([])
const describedBy = () => attrs['aria-describedby'] || field?.describedBy.value
const invalid = () => attrs['aria-invalid'] ?? field?.invalid.value
function changed(value) {
  if (props.disabled) return
  const previous = model.value
  model.value = value
  emit('input', { target: { value } })
  if (!recovery.value && /^\d{6}$/.test(value) && value !== previous) {
    nextTick(() => {
      if (!props.disabled && model.value === value && !recovery.value) {
        controls.value[0]?.closest('form')?.requestSubmit()
      }
    })
  }
}
function focus(index) { nextTick(() => controls.value[Math.max(0, Math.min(5, index))]?.focus()) }
function update(event, index) {
  if (props.disabled) return
  const raw = event.target.value.replace(/\s/g, '')
  if (props.allowRecovery && /^[a-f0-9]{10}$/i.test(raw)) {
    recovery.value = true
    emit('recovery-change', true)
    changed(raw.toLowerCase())
    return
  }
  const digits = raw.replace(/\D/g, '').slice(0, 6)
  if (digits.length > 1) {
    changed((model.value.slice(0, index) + digits + model.value.slice(index + digits.length)).slice(0, 6))
    focus(index + digits.length)
  } else {
    // Keep the code contiguous; the visible boxes never hide gaps in a submitted value.
    const position = Math.min(index, model.value.length)
    changed((model.value.slice(0, position) + digits + model.value.slice(position + 1)).slice(0, 6))
    if (digits) focus(position + 1)
  }
  event.target.value = model.value[index] || ''
}
function paste(event, index) {
  event.preventDefault()
  update({ target: { value: event.clipboardData.getData('text') } }, index)
}
function keydown(event, index) {
  if (props.disabled) return
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') { event.preventDefault(); focus(index + (event.key === 'ArrowLeft' ? -1 : 1)) }
  if (event.key === 'Backspace') {
    event.preventDefault()
    const position = model.value[index] ? index : index - 1
    if (position >= 0) { changed(model.value.slice(0, position) + model.value.slice(position + 1)); focus(position) }
  }
}
function toggle() {
  if (props.disabled) return
  recovery.value = !recovery.value
  emit('recovery-change', recovery.value)
  changed('')
  nextTick(() => { if (!recovery.value) focus(0) })
}
</script>
<template>
  <div class="space-y-3">
    <TextInput v-if="recovery" v-bind="attrs" :model-value="model" :disabled="disabled" type="text" inputmode="text" maxlength="10" autocomplete="off" @update:model-value="changed(String($event).replace(/\s/g, '').toLowerCase().slice(0, 10))" />
    <div v-else class="grid grid-cols-6 gap-2">
      <input v-for="index in 6" :key="index" :ref="element => controls[index - 1] = element" :id="index === 1 ? (attrs.id || field?.controlId.value) : undefined" :name="index === 1 ? (attrs.name || 'code') : undefined" :value="model[index - 1] || ''" :disabled="disabled" :aria-label="index === 1 && field ? undefined : t('otp.digit', { index })" :aria-describedby="describedBy()" :aria-invalid="invalid()" type="text" inputmode="numeric" :autocomplete="index === 1 ? 'one-time-code' : 'off'" maxlength="10" class="h-12 w-full min-w-0 rounded-lg border border-gray-300 bg-white text-center text-xl font-semibold text-gray-900 focus:border-brand-500 focus:outline-none focus:ring-4 focus:ring-brand-100 aria-[invalid=true]:border-error-500 disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900 dark:text-white" @focus="$event.target.select()" @input="update($event, index - 1)" @paste="paste($event, index - 1)" @keydown="keydown($event, index - 1)" />
    </div>
    <p v-if="disabled" role="status" class="flex items-center gap-2 text-sm text-gray-500"><LoaderCircle class="h-4 w-4 animate-spin" aria-hidden="true" />{{ t('auth.verifying') }}</p>
    <button v-if="allowRecovery" type="button" :disabled="disabled" :aria-pressed="recovery" class="text-sm font-medium text-brand-600 hover:text-brand-500 disabled:opacity-50 dark:text-brand-400" @click="toggle">{{ t(recovery ? 'otp.use_otp' : 'otp.use_recovery') }}</button>
  </div>
</template>
