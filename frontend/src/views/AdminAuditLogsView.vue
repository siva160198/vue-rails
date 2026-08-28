<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch, currentUser } from '../services/api'
import { toast } from '../services/toast'
import { t } from '../services/i18n'

const router = useRouter()
const admin = ref(null)
const logs = ref([])
const logoutLoading = ref(false)

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
    logs.value = (await apiFetch('/api/v1/admin/audit_logs')).audit_logs
  } catch (requestError) {
    toast.error(requestError.message)
  }
})
</script>

<template>
  <AdminLayout :email="admin?.email_address" :permissions="admin?.permissions" :logout-loading="logoutLoading" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t('audit.title') }}</h1><p class="mt-1 text-sm text-gray-500">{{ t('audit.subtitle') }}</p></div>
      <div class="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
        <table class="w-full text-left text-sm"><thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-5 py-3">{{ t('audit.action') }}</th><th class="px-5 py-3">{{ t('audit.actor') }}</th><th class="px-5 py-3">{{ t('audit.target') }}</th><th class="px-5 py-3">IP</th><th class="px-5 py-3">{{ t('audit.time') }}</th></tr></thead>
          <tbody><tr v-for="log in logs" :key="log.id" class="border-t border-gray-100 dark:border-gray-800"><td class="px-5 py-4 font-medium dark:text-white">{{ log.action }}</td><td class="px-5 py-4 text-gray-500">{{ log.actor_email || 'System' }}</td><td class="px-5 py-4 text-gray-500">{{ log.auditable_type ? `${log.auditable_type} #${log.auditable_id}` : '—' }}</td><td class="px-5 py-4 text-gray-500">{{ log.ip_address || '—' }}</td><td class="px-5 py-4 text-gray-500">{{ new Date(log.created_at).toLocaleString() }}</td></tr></tbody>
        </table>
        <p v-if="logs.length === 0" class="p-8 text-center text-sm text-gray-500">{{ t('audit.empty') }}</p>
      </div>
    </div>
  </AdminLayout>
</template>
