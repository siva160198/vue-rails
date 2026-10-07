<script setup>
import { reactive, watch } from 'vue'
import FormField from './FormField.vue'
import TextInput from './TextInput.vue'
import AsyncButton from './AsyncButton.vue'
import { useFormErrors } from '../services/formErrors'
import { reportContext } from '../services/reportContext'
import { toast } from '../services/toast'
import { t } from '../services/i18n'

const props = defineProps({ range: { type: Object, required: true }, loading: Boolean })
const emit = defineEmits(['change'])
const form = reactive({ start_date: '', end_date: '' })
const errors = useFormErrors()
watch(() => props.range, range => Object.assign(form, { start_date: range.start_date, end_date: range.end_date }), { immediate: true })
async function submit(event) {
  if (props.loading || (form.start_date === props.range.start_date && form.end_date === props.range.end_date)) return
  const normalized = reportContext(form)
  const invalid = normalized.start_date !== form.start_date || normalized.end_date !== form.end_date
  if (!await errors.validate({ start_date: () => invalid ? t('report.invalid_range') : '', end_date: () => invalid ? t('report.invalid_range') : '' }, event.target)) { toast.warning(t('validation.fix_fields')); return }
  if (!props.loading) emit('change', { ...form })
}
</script>
<template>
  <form class="flex flex-wrap items-end gap-3" novalidate @submit.prevent="submit">
    <FormField :label="t('report.start')" :error="errors.errorFor('start_date')"><TextInput v-model="form.start_date" name="start_date" type="date" :disabled="loading" @input="errors.clearErrors()" /></FormField>
    <FormField :label="t('report.end')" :error="errors.errorFor('end_date')"><TextInput v-model="form.end_date" name="end_date" type="date" :disabled="loading" @input="errors.clearErrors()" /></FormField>
    <AsyncButton type="submit" :loading="loading" :disabled="form.start_date === range.start_date && form.end_date === range.end_date" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t('report.apply') }}</AsyncButton>
  </form>
</template>
