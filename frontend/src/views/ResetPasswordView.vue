<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { apiFetch } from '../services/api'

const route = useRoute()
const router = useRouter()
const token = typeof route.query.token === 'string' ? route.query.token : ''
const password = ref('')
const passwordConfirmation = ref('')
const state = ref('checking')
const error = ref('')
const loading = ref(false)

onMounted(async () => {
  if (!token) {
    state.value = 'invalid'
    error.value = 'Link reset tidak lengkap.'
    return
  }

  try {
    await apiFetch(`/api/v1/password_reset?token=${encodeURIComponent(token)}`)
    state.value = 'valid'
  } catch (requestError) {
    state.value = 'invalid'
    error.value = requestError.message
  }
})

async function resetPassword() {
  error.value = ''
  if (password.value !== passwordConfirmation.value) {
    error.value = 'Konfirmasi password tidak cocok.'
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
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <section class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-emerald-600">Account recovery</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">Buat password baru</h1>
      <p v-if="state === 'checking'" class="mt-6 text-sm text-slate-500">Memverifikasi link reset…</p>
      <form v-else-if="state === 'valid'" class="mt-8" @submit.prevent="resetPassword">
        <div class="space-y-5">
          <label class="block text-sm font-medium">Password baru<input v-model="password" type="password" autocomplete="new-password" minlength="12" required autofocus class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /><span class="mt-1 block text-xs text-slate-500">Minimal 12 karakter.</span></label>
          <label class="block text-sm font-medium">Konfirmasi password<input v-model="passwordConfirmation" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
        </div>
        <p v-if="error" class="mt-5 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
        <button :disabled="loading" class="mt-6 w-full rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white hover:bg-emerald-600 disabled:cursor-wait disabled:opacity-60">{{ loading ? 'Menyimpan…' : 'Simpan password baru' }}</button>
      </form>
      <div v-else class="mt-6">
        <p class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
        <RouterLink to="/forgot-password" class="mt-5 block text-center text-sm font-semibold text-emerald-600 hover:text-emerald-700">Minta link reset baru</RouterLink>
      </div>
    </section>
  </main>
</template>
