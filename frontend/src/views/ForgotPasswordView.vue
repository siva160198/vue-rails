<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiFetch } from '../services/api'

const router = useRouter()
const email = ref('')
const code = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const challengeToken = ref('')
const error = ref('')
const notice = ref('')
const loading = ref(false)

async function requestReset() {
  error.value = ''
  notice.value = ''
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/password_reset', {
      method: 'POST',
      body: JSON.stringify({ email_address: email.value }),
    })
    challengeToken.value = response.challenge_token
    notice.value = response.message
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function resetPassword() {
  error.value = ''
  notice.value = ''

  if (password.value !== passwordConfirmation.value) {
    error.value = 'Konfirmasi password tidak cocok.'
    return
  }

  loading.value = true
  try {
    await apiFetch('/api/v1/password_reset', {
      method: 'PATCH',
      body: JSON.stringify({
        challenge_token: challengeToken.value,
        code: code.value,
        password: password.value,
        password_confirmation: passwordConfirmation.value,
      }),
    })
    await router.push({ path: '/login', query: { reset: 'success' } })
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

function restart() {
  challengeToken.value = ''
  code.value = ''
  password.value = ''
  passwordConfirmation.value = ''
  error.value = ''
  notice.value = ''
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <form class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60" @submit.prevent="challengeToken ? resetPassword() : requestReset()">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-emerald-600">Account recovery</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">{{ challengeToken ? 'Buat password baru' : 'Lupa kata sandi' }}</h1>
      <p class="mt-2 text-sm text-slate-500">{{ challengeToken ? 'Masukkan OTP dari email dan password baru Anda.' : 'Kami akan mengirim kode reset jika email terdaftar.' }}</p>

      <div v-if="!challengeToken" class="mt-8">
        <label class="block text-sm font-medium">Email<input v-model="email" type="email" autocomplete="email" required autofocus class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
      </div>

      <div v-else class="mt-8 space-y-5">
        <label class="block text-sm font-medium">Kode OTP<input v-model="code" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required autofocus class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 text-center text-2xl font-bold tracking-[0.45em] outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
        <label class="block text-sm font-medium">Password baru<input v-model="password" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /><span class="mt-1 block text-xs text-slate-500">Minimal 12 karakter.</span></label>
        <label class="block text-sm font-medium">Konfirmasi password<input v-model="passwordConfirmation" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
      </div>

      <p v-if="error" class="mt-5 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
      <p v-if="notice" class="mt-5 rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{{ notice }}</p>
      <button :disabled="loading" class="mt-6 w-full rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white hover:bg-emerald-600 disabled:cursor-wait disabled:opacity-60">{{ loading ? 'Memproses…' : challengeToken ? 'Simpan password baru' : 'Kirim kode reset' }}</button>

      <div class="mt-5 flex items-center justify-between text-sm">
        <button v-if="challengeToken" type="button" class="font-medium text-slate-500 hover:text-slate-900" @click="restart">Minta kode baru</button>
        <RouterLink to="/login" class="ml-auto font-semibold text-emerald-600 hover:text-emerald-700">Kembali ke login</RouterLink>
      </div>
    </form>
  </main>
</template>
