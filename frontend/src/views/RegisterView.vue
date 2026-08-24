<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiFetch } from '../services/api'

const router = useRouter()
const email = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const code = ref('')
const challengeToken = ref('')
const emailHint = ref('')
const error = ref('')
const notice = ref('')
const loading = ref(false)

async function register() {
  error.value = ''
  notice.value = ''

  if (password.value !== passwordConfirmation.value) {
    error.value = 'Konfirmasi password tidak cocok.'
    return
  }

  loading.value = true
  try {
    const response = await apiFetch('/api/v1/registration', {
      method: 'POST',
      body: JSON.stringify({
        email_address: email.value,
        password: password.value,
        password_confirmation: passwordConfirmation.value,
      }),
    })
    challengeToken.value = response.challenge_token
    emailHint.value = response.email_hint
    notice.value = `Kode verifikasi telah dikirim ke ${response.email_hint}.`
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function verifyOtp() {
  error.value = ''
  notice.value = ''
  loading.value = true
  try {
    await apiFetch('/api/v1/session/verify_otp', {
      method: 'POST',
      body: JSON.stringify({ challenge_token: challengeToken.value, code: code.value }),
    })
    await router.push('/')
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function resendOtp() {
  error.value = ''
  notice.value = ''
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/session/resend_otp', {
      method: 'POST',
      body: JSON.stringify({ challenge_token: challengeToken.value }),
    })
    challengeToken.value = response.challenge_token
    code.value = ''
    notice.value = `Kode baru telah dikirim ke ${response.email_hint}.`
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <form class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60" @submit.prevent="challengeToken ? verifyOtp() : register()">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-emerald-600">Member registration</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">{{ challengeToken ? 'Verifikasi email' : 'Buat akun' }}</h1>
      <p class="mt-2 text-sm text-slate-500">
        {{ challengeToken ? `Masukkan kode 6 digit yang dikirim ke ${emailHint}.` : 'Daftar sebagai member baru.' }}
      </p>

      <div v-if="!challengeToken" class="mt-8 space-y-5">
        <label class="block text-sm font-medium">Email<input v-model="email" type="email" autocomplete="email" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
        <label class="block text-sm font-medium">Password<input v-model="password" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /><span class="mt-1 block text-xs text-slate-500">Minimal 12 karakter.</span></label>
        <label class="block text-sm font-medium">Konfirmasi password<input v-model="passwordConfirmation" type="password" autocomplete="new-password" minlength="12" required class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
      </div>

      <div v-else class="mt-8">
        <label class="block text-sm font-medium">Kode OTP<input v-model="code" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required autofocus class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 text-center text-2xl font-bold tracking-[0.45em] outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
      </div>

      <p v-if="error" class="mt-5 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>
      <p v-if="notice" class="mt-5 rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{{ notice }}</p>
      <button :disabled="loading" class="mt-6 w-full rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white hover:bg-emerald-600 disabled:cursor-wait disabled:opacity-60">{{ loading ? 'Memproses…' : challengeToken ? 'Verifikasi dan masuk' : 'Daftar' }}</button>

      <div class="mt-5 flex items-center justify-between text-sm">
        <RouterLink to="/login" class="font-medium text-slate-500 hover:text-slate-900">Sudah punya akun?</RouterLink>
        <button v-if="challengeToken" type="button" :disabled="loading" class="font-semibold text-emerald-600 hover:text-emerald-700 disabled:opacity-50" @click="resendOtp">Kirim ulang OTP</button>
      </div>
    </form>
  </main>
</template>
