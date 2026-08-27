<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch, currentUser } from '../services/api'
import { toast } from '../services/toast'

const router = useRouter()
const admin = ref(null)
const users = ref([])
const roles = ref([])
const search = ref('')
const loading = ref(false)
const canUpdate = () => admin.value?.permissions.includes('users.update')

async function loadUsers() {
  loading.value = true
  try {
    const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
    const response = await apiFetch(`/api/v1/admin/users${query}`)
    users.value = response.users
    roles.value = response.roles
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}

async function saveUser(user) {
  try {
    const response = await apiFetch(`/api/v1/admin/users/${user.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ role: user.role, active: user.active }),
    })
    Object.assign(user, response.user)
    toast.success(`${user.email_address} berhasil diperbarui.`)
  } catch (requestError) {
    toast.error(requestError.message)
  }
}

async function logout() {
  try {
    await apiFetch('/api/v1/session', { method: 'DELETE' })
    await router.push('/login')
  } catch (requestError) {
    toast.error(requestError.message)
  }
}

onMounted(async () => {
  try {
    admin.value = await currentUser()
    await loadUsers()
  } catch (requestError) {
    toast.error(requestError.message)
  }
})
</script>

<template>
  <AdminLayout :email="admin?.email_address" :permissions="admin?.permissions" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">User management</h1><p class="mt-1 text-sm text-gray-500">Kelola role dan akses akun.</p></div>
      <form class="mb-5 flex gap-3" @submit.prevent="loadUsers"><input v-model="search" type="search" placeholder="Cari email…" class="w-full max-w-md rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm outline-none focus:border-brand-400 dark:border-gray-800 dark:bg-gray-900 dark:text-white" /><button class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white">Cari</button></form>
      <div class="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
        <table class="w-full text-left text-sm"><thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-5 py-3">Email</th><th class="px-5 py-3">Role</th><th class="px-5 py-3">Status</th><th class="px-5 py-3">Verified</th><th class="px-5 py-3">Action</th></tr></thead>
          <tbody><tr v-for="user in users" :key="user.id" class="border-t border-gray-100 dark:border-gray-800"><td class="px-5 py-4 font-medium dark:text-white">{{ user.email_address }}<span v-if="user.id === admin?.id" class="ml-2 text-xs text-brand-500">Anda</span></td><td class="px-5 py-4"><select v-model="user.role" :disabled="user.id === admin?.id || !canUpdate()" class="rounded-lg border border-gray-200 bg-transparent px-3 py-2 disabled:opacity-60 dark:border-gray-700 dark:text-white"><option v-for="role in roles" :key="role.key" :value="role.key">{{ role.name }}</option></select></td><td class="px-5 py-4"><label class="inline-flex items-center gap-3" :class="user.id === admin?.id || !canUpdate() ? 'cursor-not-allowed opacity-60' : 'cursor-pointer'"><input v-model="user.active" type="checkbox" class="peer sr-only" :disabled="user.id === admin?.id || !canUpdate()" :aria-label="`Status ${user.email_address}`" /><span class="relative h-6 w-11 rounded-full bg-gray-300 transition-colors after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white after:shadow-sm after:transition-transform peer-checked:bg-success-500 peer-checked:after:translate-x-5 peer-focus-visible:ring-4 peer-focus-visible:ring-brand-100 dark:bg-gray-700 dark:peer-checked:bg-success-600"></span><span :class="user.active ? 'text-success-700 dark:text-success-500' : 'text-gray-500'" class="min-w-14 text-sm font-medium">{{ user.active ? 'Aktif' : 'Nonaktif' }}</span></label></td><td class="px-5 py-4 text-gray-500">{{ user.email_verified_at ? 'Ya' : 'Belum' }}</td><td class="px-5 py-4"><button v-if="canUpdate()" :disabled="user.id === admin?.id" class="rounded-lg bg-gray-900 px-4 py-2 text-xs font-semibold text-white disabled:opacity-40" @click="saveUser(user)">Simpan</button><span v-else class="text-xs text-gray-400">View only</span></td></tr></tbody>
        </table>
        <p v-if="!loading && users.length === 0" class="p-8 text-center text-sm text-gray-500">User tidak ditemukan.</p>
      </div>
    </div>
  </AdminLayout>
</template>
