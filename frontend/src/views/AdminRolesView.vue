<script setup>
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch, currentUser } from '../services/api'

const router = useRouter()
const admin = ref(null)
const roles = ref([])
const loading = ref(false)
const error = ref('')
const notice = ref('')
const form = reactive({ key: '', name: '', description: '' })

function sanitizeKey(event) {
  form.key = event.target.value.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
}

async function loadRoles() {
  loading.value = true
  error.value = ''
  try {
    roles.value = (await apiFetch('/api/v1/admin/roles')).roles
  } catch (requestError) {
    error.value = requestError.message
  } finally {
    loading.value = false
  }
}

async function createRole() {
  error.value = ''
  notice.value = ''
  try {
    await apiFetch('/api/v1/admin/roles', { method: 'POST', body: JSON.stringify(form) })
    Object.assign(form, { key: '', name: '', description: '' })
    notice.value = 'Role baru berhasil dibuat.'
    await loadRoles()
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function saveRole(role) {
  error.value = ''
  notice.value = ''
  try {
    const response = await apiFetch(`/api/v1/admin/roles/${role.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ name: role.name, description: role.description }),
    })
    Object.assign(role, response.role)
    notice.value = `${role.name} berhasil diperbarui.`
  } catch (requestError) {
    error.value = requestError.message
  }
}

async function deleteRole(role) {
  if (!window.confirm(`Hapus role ${role.name}?`)) return
  error.value = ''
  notice.value = ''
  try {
    await apiFetch(`/api/v1/admin/roles/${role.id}`, { method: 'DELETE' })
    roles.value = roles.value.filter((item) => item.id !== role.id)
    notice.value = `${role.name} berhasil dihapus.`
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
  await loadRoles()
})
</script>

<template>
  <AdminLayout :email="admin?.email_address" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Role management</h1><p class="mt-1 text-sm text-gray-500">Buat role dan gunakan role tersebut pada user management.</p></div>
      <p v-if="error" class="mb-4 rounded-xl bg-error-50 p-4 text-sm text-error-700">{{ error }}</p>
      <p v-if="notice" class="mb-4 rounded-xl bg-success-50 p-4 text-sm text-success-700">{{ notice }}</p>

      <form class="mb-6 grid gap-4 rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03] md:grid-cols-2" @submit.prevent="createRole">
        <div><label class="mb-2 block text-sm font-medium dark:text-white">Nama role</label><input v-model="form.name" required class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm dark:border-gray-700 dark:text-white" placeholder="Contoh: Editor" /></div>
        <div><label class="mb-2 block text-sm font-medium dark:text-white">Key</label><input v-model="form.key" required pattern="[a-z0-9_]+" class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm dark:border-gray-700 dark:text-white" placeholder="editor" @input="sanitizeKey" /><p class="mt-1 text-xs text-gray-400">Input otomatis dibatasi ke huruf kecil, angka, dan underscore.</p></div>
        <div class="md:col-span-2"><label class="mb-2 block text-sm font-medium dark:text-white">Deskripsi</label><textarea v-model="form.description" rows="2" class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm dark:border-gray-700 dark:text-white" /></div>
        <div class="md:col-span-2"><button class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600">Tambah role</button></div>
      </form>

      <div class="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
        <table class="w-full text-left text-sm">
          <thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-5 py-3">Role</th><th class="px-5 py-3">Key</th><th class="px-5 py-3">Deskripsi</th><th class="px-5 py-3">Users</th><th class="px-5 py-3">Action</th></tr></thead>
          <tbody><tr v-for="role in roles" :key="role.id" class="border-t border-gray-100 dark:border-gray-800">
            <td class="px-5 py-4"><input v-model="role.name" class="rounded-lg border border-gray-200 bg-transparent px-3 py-2 font-medium dark:border-gray-700 dark:text-white" /></td>
            <td class="px-5 py-4 font-mono text-xs text-gray-500">{{ role.key }}<span v-if="role.system" class="ml-2 rounded-full bg-brand-50 px-2 py-1 text-[10px] text-brand-600">SYSTEM</span></td>
            <td class="px-5 py-4"><input v-model="role.description" class="min-w-64 rounded-lg border border-gray-200 bg-transparent px-3 py-2 dark:border-gray-700 dark:text-white" /></td>
            <td class="px-5 py-4 text-gray-500">{{ role.users_count }}</td>
            <td class="px-5 py-4"><div class="flex gap-2"><button class="rounded-lg bg-gray-900 px-3 py-2 text-xs font-semibold text-white" @click="saveRole(role)">Simpan</button><button :disabled="role.system || role.users_count > 0" class="rounded-lg border border-error-200 px-3 py-2 text-xs font-semibold text-error-700 disabled:cursor-not-allowed disabled:opacity-40" @click="deleteRole(role)">Hapus</button></div></td>
          </tr></tbody>
        </table>
        <p v-if="!loading && roles.length === 0" class="p-8 text-center text-sm text-gray-500">Belum ada role.</p>
      </div>
    </div>
  </AdminLayout>
</template>
