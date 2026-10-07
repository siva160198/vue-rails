<script setup>
import { computed, onBeforeUnmount, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ReportDateFilter from "../components/ReportDateFilter.vue";
import ReportLineChart from "../components/ReportLineChart.vue";
import { reportContext } from "../services/reportContext";
import {
  Activity,
  ArrowDownRight,
  ArrowUpRight,
  Database,
  ShieldCheck,
  Users,
} from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { apiFetch } from "../services/api";
import { toast } from "../services/toast";
import { t } from "../services/i18n";
import DataTable from "../components/DataTable.vue";
import AsyncButton from "../components/AsyncButton.vue";

const dashboard = ref(null);
const loadFailed = ref(false);
const reportLoading = ref(false);
const route = useRoute();
const router = useRouter();
const range = computed(() => reportContext(route.query));
let controller;
let sequence = 0;
function changeRange(value) { router.replace({ query: { ...route.query, ...value } }); }

const cards = computed(() =>
  dashboard.value
    ? [
        {
          label: t("dashboard.total_users"),
          value: dashboard.value.metrics.users,
          change: t("dashboard.live"),
          trend: "up",
          icon: Users,
        },
        {
          label: t("dashboard.active_sessions"),
          value: dashboard.value.metrics.active_sessions,
          change: t("dashboard.live"),
          trend: "up",
          icon: Activity,
        },
        {
          label: t("dashboard.database"),
          value: "PostgreSQL",
          change: t("dashboard.connected"),
          trend: "up",
          icon: Database,
        },
        {
          label: t("dashboard.authorization"),
          value: "Pundit",
          change: t("dashboard.protected"),
          trend: "up",
          icon: ShieldCheck,
        },
      ]
    : [],
);
const activityColumns = computed(() => [
  { key: "event", label: t("dashboard.event") },
  { key: "account", label: t("dashboard.account") },
  { key: "status", label: t("common.status") },
  { key: "time", label: t("audit.time") },
]);
const activityItems = computed(() =>
  dashboard.value
    ? [
        {
          id: "current-session",
          event: t("dashboard.session_authenticated"),
          account: dashboard.value.user.email_address,
          status: t("dashboard.success"),
          time: t("common.just_now"),
        },
      ]
    : [],
);

async function loadDashboard() {
  const request = ++sequence;
  controller?.abort();
  controller = new AbortController();
  reportLoading.value = true;
  loadFailed.value = false;
  try {
    const query = new URLSearchParams({ start_date: range.value.start_date, end_date: range.value.end_date });
    const response = await apiFetch('/api/v1/admin/dashboard?' + query, { signal: controller.signal });
    if (request === sequence) dashboard.value = response;
  } catch (error) {
    if (request === sequence && error.code !== 'REQUEST_ABORTED' && error.name !== 'AbortError') { loadFailed.value = true; toast.error(error.message); }
  } finally { if (request === sequence) reportLoading.value = false; }
}
watch(() => [route.query.start_date, route.query.end_date], loadDashboard, { immediate: true });
onBeforeUnmount(() => { sequence++; controller?.abort(); });
</script>

<template>
  <AdminLayout>
    <div class="mx-auto max-w-[1536px]">
      <div
        class="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-center"
      >
        <div>
          <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">
            {{ t("dashboard.title") }}
          </h1>
          <p class="mt-1 text-sm text-gray-500">
            {{ t("dashboard.subtitle") }}
          </p>
        </div>
        <div class="flex items-center gap-2 text-sm text-gray-500">
          <span>{{ t("nav.home") }}</span
          ><span>/</span
          ><span class="text-brand-500">{{ t("dashboard.title") }}</span>
        </div>
      </div>

      <div v-if="loadFailed && !dashboard" class="py-12 text-center text-sm text-gray-500">
        <p>{{ t("dashboard.load_failed") }}</p>
        <AsyncButton class="mt-3 rounded-lg border border-gray-200 px-4 py-2" :loading="reportLoading" @click="loadDashboard">{{ t('common.retry') }}</AsyncButton>
      </div>
      <div
        v-else-if="!dashboard"
        class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
      >
        <div
          v-for="item in 4"
          :key="item"
          class="h-40 animate-pulse rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]"
        ></div>
      </div>

      <template v-else>
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <article
            v-for="card in cards"
            :key="card.label"
            class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]"
          >
            <div
              class="flex h-12 w-12 items-center justify-center rounded-xl bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-white"
            >
              <component :is="card.icon" :size="23" />
            </div>
            <div class="mt-5 flex items-end justify-between">
              <div>
                <p class="text-sm text-gray-500">{{ card.label }}</p>
                <p
                  class="mt-1 text-2xl font-bold text-gray-900 dark:text-white"
                >
                  {{ card.value }}
                </p>
              </div>
              <span
                class="flex items-center gap-1 rounded-full bg-brand-50 px-2 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10"
                ><ArrowUpRight
                  v-if="card.trend === 'up'"
                  :size="13"
                /><ArrowDownRight v-else :size="13" />{{ card.change }}</span
              >
            </div>
          </article>
        </div>

        <div class="mt-6 grid gap-6 xl:grid-cols-3">
          <section
            class="rounded-2xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-white/[0.03] xl:col-span-2"
          >
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                  {{ t("dashboard.overview") }}
                </h2>
                <p class="mt-1 text-sm text-gray-500">
                  {{ t("dashboard.system_activity") }}
                </p>
              </div>
            </div>
            <div class="mt-4"><ReportDateFilter :range="range" :loading="reportLoading" @change="changeRange" /></div>
            <ReportLineChart :title="t('report.registrations')" :current="dashboard.report?.current || []" :previous="dashboard.report?.previous || []" :loading="reportLoading" :error="loadFailed" @retry="loadDashboard" />
          </section>

          <section
            class="rounded-2xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-white/[0.03]"
          >
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {{ t("dashboard.quick_status") }}
            </h2>
            <p class="mt-1 text-sm text-gray-500">
              {{ t("dashboard.backend_services") }}
            </p>
            <div class="mt-6 space-y-5">
              <div
                v-for="service in [
                  'Rails JSON API',
                  'PostgreSQL',
                  'Rails Authentication',
                  'Pundit',
                ]"
                :key="service"
                class="flex items-center justify-between border-b border-gray-100 pb-4 last:border-0 dark:border-gray-800"
              >
                <div class="flex items-center gap-3">
                  <span
                    class="h-2.5 w-2.5 rounded-full bg-brand-500 ring-4 ring-brand-50 dark:ring-brand-500/10"
                  ></span
                  ><span
                    class="text-sm font-medium text-gray-700 dark:text-gray-300"
                    >{{ service }}</span
                  >
                </div>
                <span class="text-xs text-gray-400">{{
                  t("dashboard.operational")
                }}</span>
              </div>
            </div>
          </section>
        </div>

        <section
          class="mt-6 overflow-hidden rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]"
        >
          <div class="border-b border-gray-200 px-6 py-5 dark:border-gray-800">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {{ t("dashboard.recent_activity") }}
            </h2>
            <p class="mt-1 text-sm text-gray-500">
              {{ t("dashboard.auth_events") }}
            </p>
          </div>
          <DataTable
            :items="activityItems"
            :columns="activityColumns"
            :searchable="false"
            ><template #cell-event="{ value }"
              ><span class="font-medium text-gray-800 dark:text-gray-200">{{
                value
              }}</span></template
            ><template #cell-status="{ value }"
              ><span
                class="rounded-full bg-brand-50 px-2.5 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10"
                >{{ value }}</span
              ></template
            ></DataTable
          >
        </section>
      </template>
    </div>
  </AdminLayout>
</template>
