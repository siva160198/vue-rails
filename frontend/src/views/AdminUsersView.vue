<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch, currentUser } from '../services/api'

const router = useRouter()
const admin = ref(null)
const users = ref([])
const search = ref('')
const loading = ref(false)
const error = ref('')
const notice = ref('')

async function loadUsers() {
  loading.value = true
  error.value = ''
  try {
    const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
    users.value = (await apiFetch(`/api/v1/admin/users${query}`)).users
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function saveUser(user) {
  error.value = ''
  notice.value = ''
  try {
    const response = await apiFetch(`/api/v1/admin/users/${user.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ role: user.role, active: user.active }),
    })
    Object.assign(user, response.user)
    notice.value = `${user.email_address} berhasil diperbarui.`
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function logout() {
  await apiFetch('/api/v1/session', { method: 'DELETE' })
  await router.push('/login')
}

onMounted(async () => {
  admin.value = await currentUser()
  await loadUsers()
})
</script>

<template>
  <AdminLayout :email="admin?.email_address" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">User management</h1><p class="mt-1 text-sm text-gray-500">Kelola role dan akses akun.</p></div>
      <form class="mb-5 flex gap-3" @submit.prevent="loadUsers"><input v-model="search" type="search" placeholder="Cari email…" class="w-full max-w-md rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm outline-none focus:border-brand-400 dark:border-gray-800 dark:bg-gray-900 dark:text-white" /><button class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white">Cari</button></form>
      <p v-if="error" class="mb-4 rounded-xl bg-error-50 p-4 text-sm text-error-700">{{ error }}</p>
      <p v-if="notice" class="mb-4 rounded-xl bg-success-50 p-4 text-sm text-success-700">{{ notice }}</p>
      <div class="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
        <table class="w-full text-left text-sm"><thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-5 py-3">Email</th><th class="px-5 py-3">Role</th><th class="px-5 py-3">Status</th><th class="px-5 py-3">Verified</th><th class="px-5 py-3">Action</th></tr></thead>
          <tbody><tr v-for="user in users" :key="user.id" class="border-t border-gray-100 dark:border-gray-800"><td class="px-5 py-4 font-medium dark:text-white">{{ user.email_address }}<span v-if="user.id === admin?.id" class="ml-2 text-xs text-brand-500">Anda</span></td><td class="px-5 py-4"><select v-model="user.role" :disabled="user.id === admin?.id" class="rounded-lg border border-gray-200 bg-transparent px-3 py-2 dark:border-gray-700 dark:text-white"><option value="member">Member</option><option value="admin">Admin</option></select></td><td class="px-5 py-4"><label class="flex items-center gap-2"><input v-model="user.active" type="checkbox" :disabled="user.id === admin?.id" />{{ user.active ? 'Aktif' : 'Nonaktif' }}</label></td><td class="px-5 py-4 text-gray-500">{{ user.email_verified_at ? 'Ya' : 'Belum' }}</td><td class="px-5 py-4"><button :disabled="user.id === admin?.id" class="rounded-lg bg-gray-900 px-4 py-2 text-xs font-semibold text-white disabled:opacity-40" @click="saveUser(user)">Simpan</button></td></tr></tbody>
        </table>
        <p v-if="!loading && users.length === 0" class="p-8 text-center text-sm text-gray-500">User tidak ditemukan.</p>
      </div>
    </div>
  </AdminLayout>
</template>
