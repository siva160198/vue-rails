<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch, currentUser } from '../services/api'
import { confirmToast, toast } from '../services/toast'
import AsyncButton from '../components/AsyncButton.vue'
import PermissionPicker from '../components/PermissionPicker.vue'
import { hasChanges, snapshot } from '../services/changeTracking'
import { t } from '../services/i18n'

const router = useRouter()
const admin = ref(null)
const roles = ref([])
const permissions = ref([])
const loading = ref(false)
const creating = ref(false)
const savingRoleIds = ref(new Set())
const deletingRoleIds = ref(new Set())
const logoutLoading = ref(false)
const roleSnapshots = ref(new Map())
const form = reactive({ key: '', name: '', description: '', permission_keys: [] })
const canManage = () => admin.value?.permissions.includes('roles.manage')
const roleState = (role) => ({ name: role.name, description: role.description || '', permission_keys: role.permission_keys })
const hasRoleChanges = (role) => hasChanges(roleState(role), roleSnapshots.value.get(role.id))
const canCreate = computed(() => form.name.trim().length > 0 && /^[a-z0-9_]+$/.test(form.key))

function sanitizeKey(event) {
  form.key = event.target.value.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
}

async function loadRoles() {
  if (loading.value) return
  loading.value = true
  try {
    const response = await apiFetch('/api/v1/admin/roles')
    roles.value = response.roles
    permissions.value = response.permissions
    roleSnapshots.value = new Map(response.roles.map((role) => [role.id, snapshot(roleState(role))]))
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    loading.value = false
  }
}

async function createRole() {
  if (creating.value || !canCreate.value) return
  creating.value = true
  try {
    await apiFetch('/api/v1/admin/roles', { method: 'POST', body: JSON.stringify(form) })
    Object.assign(form, { key: '', name: '', description: '', permission_keys: [] })
    toast.success(t('roles.created'))
    await loadRoles()
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    creating.value = false
  }
}

async function saveRole(role) {
  if (savingRoleIds.value.has(role.id) || !hasRoleChanges(role)) return
  savingRoleIds.value = new Set(savingRoleIds.value).add(role.id)
  try {
    const response = await apiFetch(`/api/v1/admin/roles/${role.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ name: role.name, description: role.description, permission_keys: role.permission_keys }),
    })
    Object.assign(role, response.role)
    roleSnapshots.value = new Map(roleSnapshots.value).set(role.id, snapshot(roleState(role)))
    toast.success(t('roles.updated', { name: role.name }))
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    const nextIds = new Set(savingRoleIds.value)
    nextIds.delete(role.id)
    savingRoleIds.value = nextIds
  }
}

async function deleteRole(role) {
  if (deletingRoleIds.value.has(role.id)) return
  if (!await confirmToast(t('roles.confirm_delete', { name: role.name }), { confirmLabel: t('common.delete') })) return
  deletingRoleIds.value = new Set(deletingRoleIds.value).add(role.id)
  try {
    await apiFetch(`/api/v1/admin/roles/${role.id}`, { method: 'DELETE' })
    roles.value = roles.value.filter((item) => item.id !== role.id)
    toast.success(t('roles.deleted', { name: role.name }))
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    const nextIds = new Set(deletingRoleIds.value)
    nextIds.delete(role.id)
    deletingRoleIds.value = nextIds
  }
}

async function logout() {
  if (logoutLoading.value) return
  logoutLoading.value = true
  try {
    await apiFetch('/api/v1/session', { method: 'DELETE' })
    await router.push('/login')
  } catch (requestError) {
    toast.error(requestError.message)
  } finally {
    logoutLoading.value = false
  }
}

onMounted(async () => {
  try {
    admin.value = await currentUser()
    await loadRoles()
  } catch (requestError) {
    toast.error(requestError.message)
  }
})
</script>

<template>
  <AdminLayout :email="admin?.email_address" :permissions="admin?.permissions" :logout-loading="logoutLoading" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t('roles.title') }}</h1><p class="mt-1 text-sm text-gray-500">{{ t('roles.subtitle') }}</p></div>

      <form v-if="canManage()" class="mb-6 grid gap-4 rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03] md:grid-cols-2" @submit.prevent="createRole">
        <div><label class="mb-2 block text-sm font-medium dark:text-white">{{ t('roles.name') }}</label><input v-model="form.name" :disabled="creating" required class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white" :placeholder="t('roles.name_placeholder')" /></div>
        <div><label class="mb-2 block text-sm font-medium dark:text-white">{{ t('roles.key') }}</label><input v-model="form.key" :disabled="creating" required pattern="[a-z0-9_]+" class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white" placeholder="editor" @input="sanitizeKey" /><p class="mt-1 text-xs text-gray-400">{{ t('roles.key_help') }}</p></div>
        <div class="md:col-span-2"><label class="mb-2 block text-sm font-medium dark:text-white">{{ t('roles.description') }}</label><textarea v-model="form.description" :disabled="creating" rows="2" class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white" /></div>
        <fieldset :disabled="creating" class="md:col-span-2 disabled:opacity-60"><legend class="mb-3 text-sm font-medium dark:text-white">{{ t('roles.permissions') }}</legend><PermissionPicker v-model="form.permission_keys" :permissions="permissions" :disabled="creating" /></fieldset>
        <div class="md:col-span-2"><AsyncButton type="submit" :loading="creating" :disabled="!canCreate" loading-text="Menambahkan…" class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600">Tambah role</AsyncButton></div>
      </form>

      <div class="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
        <table class="w-full text-left text-sm">
          <thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-5 py-3">Role</th><th class="px-5 py-3">Key</th><th class="px-5 py-3">Deskripsi</th><th class="px-5 py-3">Users</th><th class="px-5 py-3">Action</th></tr></thead>
          <tbody><tr v-for="role in roles" :key="role.id" class="border-t border-gray-100 dark:border-gray-800">
            <td class="px-5 py-4"><input v-model="role.name" :disabled="!canManage() || savingRoleIds.has(role.id) || deletingRoleIds.has(role.id)" class="rounded-lg border border-gray-200 bg-transparent px-3 py-2 font-medium disabled:opacity-60 dark:border-gray-700 dark:text-white" /></td>
            <td class="px-5 py-4 font-mono text-xs text-gray-500">{{ role.key }}<span v-if="role.system" class="ml-2 rounded-full bg-brand-50 px-2 py-1 text-[10px] text-brand-600">SYSTEM</span></td>
            <td class="px-5 py-4"><input v-model="role.description" :disabled="!canManage() || savingRoleIds.has(role.id) || deletingRoleIds.has(role.id)" class="min-w-64 rounded-lg border border-gray-200 bg-transparent px-3 py-2 disabled:opacity-60 dark:border-gray-700 dark:text-white" /><div class="mt-3 min-w-96"><PermissionPicker v-model="role.permission_keys" :permissions="permissions" :disabled="!canManage() || role.key === 'admin' || savingRoleIds.has(role.id) || deletingRoleIds.has(role.id)" /></div></td>
            <td class="px-5 py-4 text-gray-500">{{ role.users_count }}</td>
            <td class="px-5 py-4"><div v-if="canManage()" class="flex gap-2"><AsyncButton :loading="savingRoleIds.has(role.id)" :disabled="deletingRoleIds.has(role.id) || !hasRoleChanges(role)" loading-text="Menyimpan…" class="rounded-lg bg-gray-900 px-3 py-2 text-xs font-semibold text-white" @click="saveRole(role)">Simpan</AsyncButton><AsyncButton :loading="deletingRoleIds.has(role.id)" :disabled="role.system || role.users_count > 0 || savingRoleIds.has(role.id)" loading-text="Menghapus…" class="rounded-lg border border-error-200 px-3 py-2 text-xs font-semibold text-error-700 disabled:opacity-40" @click="deleteRole(role)">Hapus</AsyncButton></div><span v-else class="text-xs text-gray-400">View only</span></td>
          </tr></tbody>
        </table>
        <p v-if="!loading && roles.length === 0" class="p-8 text-center text-sm text-gray-500">Belum ada role.</p>
      </div>
    </div>
  </AdminLayout>
</template>
