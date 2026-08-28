<script setup>
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import AsyncButton from '../components/AsyncButton.vue'

const router = useRouter()
const email = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const code = ref('')
const challengeToken = ref('')
const emailHint = ref('')
const loading = ref(false)
const resendLoading = ref(false)
const resendIn = ref(0)
let cooldownTimer
const emailValid = computed(() => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value))
const formValid = computed(() => challengeToken.value ? /^\d{6}$/.test(code.value) : emailValid.value && password.value.length >= 12 && password.value === passwordConfirmation.value)

function startResendCooldown(seconds) {
  window.clearInterval(cooldownTimer)
  resendIn.value = Number(seconds) || 0
  if (resendIn.value <= 0) return
  cooldownTimer = window.setInterval(() => {
    resendIn.value -= 1
    if (resendIn.value <= 0) window.clearInterval(cooldownTimer)
  }, 1000)
}

async function register() {
  if (loading.value || !formValid.value) return
  if (password.value !== passwordConfirmation.value) {
    toast.warning('Konfirmasi password tidak cocok.')
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
    startResendCooldown(response.resend_in)
    toast.info(`Kode verifikasi telah dikirim ke ${response.email_hint}.`)
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}

async function verifyOtp() {
  if (loading.value || !formValid.value) return
  loading.value = true
  try {
    await apiFetch('/api/v1/session/verify_otp', {
      method: 'POST',
      body: JSON.stringify({ challenge_token: challengeToken.value, code: code.value }),
    })
    await router.push('/')
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}

async function resendOtp() {
  if (resendLoading.value || resendIn.value > 0) return
  resendLoading.value = true
  try {
    const response = await apiFetch('/api/v1/session/resend_otp', {
      method: 'POST',
      body: JSON.stringify({ challenge_token: challengeToken.value }),
    })
    challengeToken.value = response.challenge_token
    code.value = ''
    startResendCooldown(response.resend_in)
    toast.info(`Kode baru telah dikirim ke ${response.email_hint}.`)
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    resendLoading.value = false
  }
}
onBeforeUnmount(() => window.clearInterval(cooldownTimer))
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

      <AsyncButton type="submit" :loading="loading" :disabled="resendLoading || !formValid" :loading-text="challengeToken ? 'Memverifikasi…' : 'Mendaftarkan…'" class="mt-6 w-full rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white hover:bg-emerald-600">{{ challengeToken ? 'Verifikasi dan masuk' : 'Daftar' }}</AsyncButton>

      <div class="mt-5 flex items-center justify-between text-sm">
        <RouterLink to="/login" class="font-medium text-slate-500 hover:text-slate-900">Sudah punya akun?</RouterLink>
        <AsyncButton v-if="challengeToken" :loading="resendLoading" :disabled="loading || resendIn > 0" loading-text="Mengirim…" class="font-semibold text-emerald-600 hover:text-emerald-700" @click="resendOtp">{{ resendIn > 0 ? `Kirim ulang (${resendIn}s)` : 'Kirim ulang OTP' }}</AsyncButton>
      </div>
    </form>
  </main>
</template>
