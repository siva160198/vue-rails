<script setup>
import { computed, ref } from 'vue'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import AsyncButton from '../components/AsyncButton.vue'
import { t } from '../services/i18n'
import FormField from '../components/FormField.vue'
import TextInput from '../components/TextInput.vue'
import { useFormErrors } from '../services/formErrors'

const email = ref('')
const loading = ref(false)
const resetRequestForm = ref(null)
const { errorFor, clearError, validate, applyApiError } = useFormErrors()
const formValid = computed(() => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value))

async function requestReset() {
  if (loading.value) return
  const valid = await validate({ email_address: () => !email.value ? t('validation.required') : !formValid.value ? t('validation.email') : '' }, resetRequestForm.value)
  if (!valid) { toast.warning(t('validation.fix_fields')); return }
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/password_reset', {
      method: 'POST',
      body: JSON.stringify({ email_address: email.value }),
    })
    toast.success(response.message)
  } catch (requestError) {
    await applyApiError(requestError, resetRequestForm.value); toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <form ref="resetRequestForm" novalidate class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60" @submit.prevent="requestReset">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-brand-600">{{ t('auth.recovery') }}</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">{{ t('auth.forgot_title') }}</h1>
      <p class="mt-2 text-sm text-slate-500">{{ t('auth.forgot_hint') }}</p>
      <div class="mt-8">
        <FormField :label="t('auth.email')" :error="errorFor('email_address')"><TextInput v-model="email" name="email_address" :disabled="loading" type="email" autocomplete="email" required autofocus @input="clearError('email_address')" /></FormField>
      </div>
      <AsyncButton type="submit" :loading="loading" :loading-text="t('auth.sending_link')" class="mt-6 w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white hover:bg-brand-600">{{ t('auth.send_reset') }}</AsyncButton>
      <p class="mt-5 text-center text-sm"><RouterLink to="/login" class="font-semibold text-brand-600 hover:text-brand-500">{{ t('auth.back_login') }}</RouterLink></p>
    </form>
  </main>
</template>
