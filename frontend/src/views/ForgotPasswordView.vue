<script setup>
import { ref } from 'vue'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'

const email = ref('')
const loading = ref(false)

async function requestReset() {
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/password_reset', {
      method: 'POST',
      body: JSON.stringify({ email_address: email.value }),
    })
    toast.success(response.message)
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12">
    <form class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60" @submit.prevent="requestReset">
      <p class="text-sm font-semibold uppercase tracking-[0.2em] text-emerald-600">Account recovery</p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">Lupa kata sandi</h1>
      <p class="mt-2 text-sm text-slate-500">Kami akan mengirim link reset jika email terdaftar.</p>
      <div class="mt-8">
        <label class="block text-sm font-medium">Email<input v-model="email" type="email" autocomplete="email" required autofocus class="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100" /></label>
      </div>
      <button :disabled="loading" class="mt-6 w-full rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white hover:bg-emerald-600 disabled:cursor-wait disabled:opacity-60">{{ loading ? 'Memproses…' : 'Kirim link reset' }}</button>
      <p class="mt-5 text-center text-sm"><RouterLink to="/login" class="font-semibold text-emerald-600 hover:text-emerald-700">Kembali ke login</RouterLink></p>
    </form>
  </main>
</template>
