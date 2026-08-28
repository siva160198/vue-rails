<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import AsyncButton from '../components/AsyncButton.vue'

const route = useRoute()
const router = useRouter()
const email = ref('')
const password = ref('')
const code = ref('')
const challengeToken = ref('')
const emailHint = ref('')
const loading = ref(false)
const resendLoading = ref(false)
const resendIn = ref(0)
let cooldownTimer
const emailValid = computed(() => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value))
const formValid = computed(() => challengeToken.value ? /^\d{6}$/.test(code.value) : emailValid.value && password.value.length > 0)

function startResendCooldown(seconds) {
  window.clearInterval(cooldownTimer)
  resendIn.value = Number(seconds) || 0
  if (resendIn.value <= 0) return
  cooldownTimer = window.setInterval(() => {
    resendIn.value -= 1
    if (resendIn.value <= 0) window.clearInterval(cooldownTimer)
  }, 1000)
}

async function login() {
  if (loading.value || !formValid.value) return
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/session', { method: 'POST', body: JSON.stringify({ email_address: email.value, password: password.value }) })
    challengeToken.value = response.challenge_token
    emailHint.value = response.email_hint
    startResendCooldown(response.resend_in)
    toast.info(`Kode OTP telah dikirim ke ${response.email_hint}.`)
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
    const { user } = await apiFetch('/api/v1/session/verify_otp', {
      method: 'POST',
      body: JSON.stringify({ challenge_token: challengeToken.value, code: code.value }),
    })
    if (user.permissions.length === 0) {
      await apiFetch('/api/v1/session', { method: 'DELETE' })
      toast.error('Akun ini tidak memiliki permission untuk mengakses admin panel.')
      return
    }
    const defaultPath = user.permissions.includes('dashboard.view') ? '/admin'
      : user.permissions.includes('users.view') ? '/admin/users'
        : user.permissions.includes('roles.view') ? '/admin/roles' : '/admin/audit-logs'
    await router.push(route.query.redirect || defaultPath)
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
    toast.info(`Kode OTP baru telah dikirim ke ${response.email_hint}.`)
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    resendLoading.value = false
  }
}

function restartLogin() {
  window.clearInterval(cooldownTimer)
  resendIn.value = 0
  challengeToken.value = ''
  code.value = ''
}

onMounted(() => {
  if (route.query.reset === 'success') toast.success('Password berhasil diperbarui. Silakan login.')
})
onBeforeUnmount(() => window.clearInterval(cooldownTimer))
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <form class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60" @submit.prevent="challengeToken ? verifyOtp() : login()">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-brand-600">Admin access</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">{{ challengeToken ? 'Verifikasi OTP' : 'Masuk ke Tourplan' }}</h1>
      <p class="mt-2 text-sm text-slate-500">
        {{ challengeToken ? `Masukkan kode 6 digit yang dikirim ke ${emailHint}.` : 'Gunakan akun administrator Anda.' }}
      </p>
      <div v-if="!challengeToken" class="mt-8 space-y-5">
        <label class="block text-sm font-medium">Email<input v-model="email" :disabled="loading" type="email" autocomplete="email" required class="mt-2 w-full rounded-xl px-4 py-3" /></label>
        <label class="block text-sm font-medium">Password<input v-model="password" :disabled="loading" type="password" autocomplete="current-password" required class="mt-2 w-full rounded-xl px-4 py-3" /><RouterLink to="/forgot-password" class="mt-2 block text-right text-xs font-semibold text-brand-600 hover:text-brand-500">Lupa kata sandi?</RouterLink></label>
      </div>
      <div v-else class="mt-8">
        <label class="block text-sm font-medium">Kode OTP<input v-model="code" :disabled="loading" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required autofocus class="mt-2 w-full rounded-xl px-4 py-3 text-center text-2xl font-bold tracking-[0.45em]" /></label>
      </div>
      <AsyncButton type="submit" :loading="loading" :disabled="resendLoading || !formValid" :loading-text="challengeToken ? 'Memverifikasi…' : 'Masuk…'" class="mt-6 w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white hover:bg-brand-600">{{ challengeToken ? 'Verifikasi' : 'Login' }}</AsyncButton>
      <div v-if="challengeToken" class="mt-5 flex items-center justify-between text-sm">
        <button type="button" :disabled="loading" class="font-medium text-slate-500 hover:text-slate-900 disabled:opacity-50" @click="restartLogin">Kembali</button>
        <AsyncButton :loading="resendLoading" :disabled="loading || resendIn > 0" loading-text="Mengirim…" class="font-semibold text-brand-600 hover:text-brand-500" @click="resendOtp">{{ resendIn > 0 ? `Kirim ulang (${resendIn}s)` : 'Kirim ulang OTP' }}</AsyncButton>
      </div>
      <p v-else class="mt-5 text-center text-sm text-slate-500">Belum punya akun? <RouterLink to="/register" class="font-semibold text-brand-600 hover:text-brand-500">Daftar sebagai member</RouterLink></p>
    </form>
  </main>
</template>
