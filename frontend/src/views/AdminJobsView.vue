<script setup>
import { computed, ref } from "vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import DataTable from "../components/DataTable.vue";
import TableActionButton from "../components/TableActionButton.vue";
import { apiFetch } from "../services/api";
import { locale, t } from "../services/i18n";
import { useServerTable } from "../services/serverTable";
import { confirmToast, toast } from "../services/toast";

const metrics = ref({ ready: 0, scheduled: 0, claimed: 0, failed: 0, oldest_ready_at: null });
const processingIds = ref(new Set());
const { items: failures, loading, pagination, load, removeItem } = useServerTable({
  endpoint: "/api/v1/admin/jobs",
  collectionKey: "failures",
  onResponse: (payload) => { metrics.value = payload.metrics; },
});
const columns = computed(() => [
  { key: "class_name", label: t("jobs.job") },
  { key: "message", label: t("jobs.error"), sortable: false },
  { key: "created_at", label: t("jobs.failed_at") },
  { key: "action", label: t("common.action"), sortable: false },
]);

async function mutate(failure, action) {
  if (processingIds.value.has(failure.id)) return;
  const key = action === "retry" ? "jobs.confirm_retry" : "jobs.confirm_discard";
  if (!(await confirmToast(t(key), { confirmLabel: t(`jobs.${action}`) }))) return;
  processingIds.value = new Set(processingIds.value).add(failure.id);
  try {
    await apiFetch(`/api/v1/admin/jobs/${failure.id}${action === "retry" ? "/retry" : ""}`, { method: action === "retry" ? "POST" : "DELETE" });
    removeItem(failure.id);
    toast.success(t(`jobs.${action}ed`));
  } catch (error) {
    toast.error(error.message);
  } finally {
    const next = new Set(processingIds.value); next.delete(failure.id); processingIds.value = next;
  }
}
</script>

<template>
  <AdminLayout>
    <div class="mx-auto max-w-[1536px]">
      <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t("jobs.title") }}</h1>
      <p class="mt-1 text-sm text-gray-500">{{ t("jobs.subtitle") }}</p>
      <div class="my-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div v-for="key in ['ready', 'scheduled', 'claimed', 'failed']" :key="key" class="rounded-xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900">
          <p class="text-sm text-gray-500">{{ t(`jobs.${key}`) }}</p><p class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">{{ metrics[key] }}</p>
        </div>
      </div>
      <DataTable :items="failures" :columns="columns" :loading="loading" :empty-text="t('jobs.empty')" server-mode :total="pagination.total" @request="load">
        <template #cell-class_name="{ item }"><div><strong class="text-gray-800 dark:text-white">{{ item.class_name }}</strong><p class="text-xs text-gray-500">{{ item.queue_name }} · #{{ item.job_id }}</p></div></template>
        <template #cell-message="{ item }"><p class="line-clamp-2 max-w-xl text-gray-500" :title="item.message">{{ item.exception_class }}: {{ item.message }}</p></template>
        <template #cell-created_at="{ item }"><span class="text-gray-500">{{ new Date(item.created_at).toLocaleString(locale) }}</span></template>
        <template #cell-action="{ item }"><div class="flex gap-2"><TableActionButton action="save" :label="t('jobs.retry')" :accessible-label="t('jobs.retry_job', { id: item.job_id })" :loading="processingIds.has(item.id)" @click="mutate(item, 'retry')" /><TableActionButton action="delete" :label="t('jobs.discard')" :accessible-label="t('jobs.discard_job', { id: item.job_id })" :disabled="processingIds.has(item.id)" @click="mutate(item, 'discard')" /></div></template>
      </DataTable>
    </div>
  </AdminLayout>
</template>
