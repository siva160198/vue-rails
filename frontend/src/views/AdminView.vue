<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Activity, ArrowDownRight, ArrowUpRight, Database, ShieldCheck, Users } from '@lucide/vue'
import AdminLayout from '../components/admin/AdminLayout.vue'
import { apiFetch } from '../services/api'
import { toast } from '../services/toast'
import { t } from '../services/i18n'

const router = useRouter()
const dashboard = ref(null)
const loadFailed = ref(false)
const logoutLoading = ref(false)

const cards = computed(() => dashboard.value ? [
  { label: t('dashboard.total_users'), value: dashboard.value.metrics.users, change: '+0%', trend: 'up', icon: Users },
  { label: t('dashboard.active_sessions'), value: dashboard.value.metrics.active_sessions, change: t('dashboard.live'), trend: 'up', icon: Activity },
  { label: t('dashboard.database'), value: 'PostgreSQL', change: t('dashboard.connected'), trend: 'up', icon: Database },
  { label: t('dashboard.authorization'), value: 'Pundit', change: t('dashboard.protected'), trend: 'up', icon: ShieldCheck },
] : [])

onMounted(async () => {
  try { dashboard.value = await apiFetch('/api/v1/admin/dashboard') }
  catch (requestError) { loadFailed.value = true; toast.error(requestError.message) }
})

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
</script>

<template>
  <AdminLayout :email="dashboard?.user.email_address" :permissions="dashboard?.user.permissions" :logout-loading="logoutLoading" @logout="logout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t('dashboard.title') }}</h1><p class="mt-1 text-sm text-gray-500">{{ t('dashboard.subtitle') }}</p></div>
        <div class="flex items-center gap-2 text-sm text-gray-500"><span>{{ t('nav.home') }}</span><span>/</span><span class="text-brand-500">{{ t('dashboard.title') }}</span></div>
      </div>

      <p v-if="loadFailed" class="py-12 text-center text-sm text-gray-500">{{ t('dashboard.load_failed') }}</p>
      <div v-else-if="!dashboard" class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div v-for="item in 4" :key="item" class="h-40 animate-pulse rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]"></div>
      </div>

      <template v-else>
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <article v-for="card in cards" :key="card.label" class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-white"><component :is="card.icon" :size="23" /></div>
            <div class="mt-5 flex items-end justify-between"><div><p class="text-sm text-gray-500">{{ card.label }}</p><p class="mt-1 text-2xl font-bold text-gray-900 dark:text-white">{{ card.value }}</p></div><span class="flex items-center gap-1 rounded-full bg-brand-50 px-2 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10"><ArrowUpRight v-if="card.trend === 'up'" :size="13" /><ArrowDownRight v-else :size="13" />{{ card.change }}</span></div>
          </article>
        </div>

        <div class="mt-6 grid gap-6 xl:grid-cols-3">
          <section class="rounded-2xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-white/[0.03] xl:col-span-2">
            <div class="flex items-center justify-between"><div><h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t('dashboard.overview') }}</h2><p class="mt-1 text-sm text-gray-500">{{ t('dashboard.system_activity') }}</p></div><select class="rounded-lg border border-gray-200 bg-transparent px-3 py-2 text-sm text-gray-500 dark:border-gray-800"><option>{{ t('dashboard.last_days') }}</option></select></div>
            <div class="mt-8 flex h-64 items-end gap-3 border-b border-l border-gray-200 px-5 pb-0 dark:border-gray-800">
              <div v-for="(height, index) in [35, 52, 42, 68, 55, 78, 63, 88, 72, 82, 70, 94]" :key="index" class="group relative flex-1 rounded-t-md bg-brand-100 transition hover:bg-brand-500 dark:bg-brand-500/20" :style="{ height: `${height}%` }"><span class="absolute -top-7 left-1/2 hidden -translate-x-1/2 rounded bg-gray-900 px-2 py-1 text-[10px] text-white group-hover:block">{{ height }}</span></div>
            </div>
            <div class="mt-3 flex justify-between text-xs text-gray-400"><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span></div>
          </section>

          <section class="rounded-2xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-white/[0.03]">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t('dashboard.quick_status') }}</h2><p class="mt-1 text-sm text-gray-500">{{ t('dashboard.backend_services') }}</p>
            <div class="mt-6 space-y-5">
              <div v-for="service in ['Rails JSON API', 'PostgreSQL', 'Rails Authentication', 'Pundit']" :key="service" class="flex items-center justify-between border-b border-gray-100 pb-4 last:border-0 dark:border-gray-800"><div class="flex items-center gap-3"><span class="h-2.5 w-2.5 rounded-full bg-brand-500 ring-4 ring-brand-50 dark:ring-brand-500/10"></span><span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ service }}</span></div><span class="text-xs text-gray-400">{{ t('dashboard.operational') }}</span></div>
            </div>
          </section>
        </div>

        <section class="mt-6 overflow-hidden rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
          <div class="border-b border-gray-200 px-6 py-5 dark:border-gray-800"><h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t('dashboard.recent_activity') }}</h2><p class="mt-1 text-sm text-gray-500">{{ t('dashboard.auth_events') }}</p></div>
          <div class="overflow-x-auto"><table class="w-full text-left text-sm"><thead class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"><tr><th class="px-6 py-3">{{ t('dashboard.event') }}</th><th class="px-6 py-3">{{ t('dashboard.account') }}</th><th class="px-6 py-3">{{ t('common.status') }}</th><th class="px-6 py-3">{{ t('audit.time') }}</th></tr></thead><tbody><tr class="border-t border-gray-100 dark:border-gray-800"><td class="px-6 py-4 font-medium text-gray-800 dark:text-gray-200">{{ t('dashboard.session_authenticated') }}</td><td class="px-6 py-4 text-gray-500">{{ dashboard.user.email_address }}</td><td class="px-6 py-4"><span class="rounded-full bg-brand-50 px-2.5 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10">{{ t('dashboard.success') }}</span></td><td class="px-6 py-4 text-gray-500">{{ t('common.just_now') }}</td></tr></tbody></table></div>
        </section>
      </template>
    </div>
  </AdminLayout>
</template>
