<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import AsyncButton from '../components/AsyncButton.vue'
import { t } from '../services/i18n'

const route = useRoute()
const router = useRouter()
const token = typeof route.query.token === 'string' ? route.query.token : ''
const password = ref('')
const passwordConfirmation = ref('')
const state = ref('checking')
const invalidMessage = ref('')
const loading = ref(false)
const formValid = computed(() => password.value.length >= 12 && password.value === passwordConfirmation.value)

onMounted(async () => {
  if (!token) {
    state.value = 'invalid'
    invalidMessage.value = 'Link reset tidak lengkap.'
    toast.error(invalidMessage.value)
    return
  }

  try {
    await apiFetch(`/api/v1/password_reset?token=${encodeURIComponent(token)}`)
    state.value = 'valid'
  } catch (requestError) {
    state.value = 'invalid'
    invalidMessage.value = requestError.message
    toast.error(requestError.message)
  }
})

async function resetPassword() {
  if (loading.value || !formValid.value) return
  if (password.value !== passwordConfirmation.value) {
    toast.warning(t('auth.password_mismatch'))
    return
  }

  loading.value = true
  try {
    await apiFetch('/api/v1/password_reset', {
      method: 'PATCH',
      body: JSON.stringify({ token, password: password.value, password_confirmation: passwordConfirmation.value }),
    })
    await router.push({ path: '/login', query: { reset: 'success' } })
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <section class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-brand-600">{{ t('auth.recovery') }}</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">{{ t('auth.new_password_title') }}</h1>
      <p v-if="state === 'checking'" class="mt-6 text-sm text-slate-500">{{ t('auth.checking_link') }}</p>
      <form v-else-if="state === 'valid'" class="mt-8" @submit.prevent="resetPassword">
        <div class="space-y-5">
          <label class="block text-sm font-medium">{{ t('auth.new_password') }}<input v-model="password" :disabled="loading" type="password" autocomplete="new-password" minlength="12" required autofocus class="mt-2 w-full rounded-xl px-4 py-3" /><span class="mt-1 block text-xs text-slate-500">{{ t('auth.password_min') }}</span></label>
          <label class="block text-sm font-medium">{{ t('auth.confirm_password') }}<input v-model="passwordConfirmation" :disabled="loading" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl px-4 py-3" /></label>
        </div>
        <AsyncButton type="submit" :loading="loading" :disabled="!formValid" :loading-text="t('auth.saving_password')" class="mt-6 w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white hover:bg-brand-600">{{ t('auth.save_password') }}</AsyncButton>
      </form>
      <div v-else class="mt-6">
        <p class="text-sm text-slate-500">{{ invalidMessage }}</p>
        <RouterLink to="/forgot-password" class="mt-5 block text-center text-sm font-semibold text-brand-600 hover:text-brand-500">{{ t('auth.request_new_link') }}</RouterLink>
      </div>
    </section>
  </main>
</template>
