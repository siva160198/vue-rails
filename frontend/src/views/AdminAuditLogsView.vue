<script setup>
import { computed } from "vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { t } from "../services/i18n";
import DataTable from "../components/DataTable.vue";
import { useServerTable } from "../services/serverTable";

const {
  items: logs,
  loading,
  pagination,
  load: loadLogs,
} = useServerTable({
  endpoint: "/api/v1/admin/audit_logs",
  collectionKey: "audit_logs",
});
const columns = computed(() => [
  { key: "action", label: t("audit.action") },
  { key: "actor_email", label: t("audit.actor") },
  { key: "auditable_type", label: t("audit.target") },
  { key: "ip_address", label: "IP" },
  { key: "created_at", label: t("audit.time") },
]);
</script>

<template>
  <AdminLayout>
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6">
        <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">
          {{ t("audit.title") }}
        </h1>
        <p class="mt-1 text-sm text-gray-500">{{ t("audit.subtitle") }}</p>
      </div>
      <DataTable
        :items="logs"
        :columns="columns"
        :loading="loading"
        :empty-text="t('audit.empty')"
        server-mode
        :total="pagination.total"
        @request="loadLogs"
        ><template #cell-action="{ item }"
          ><span class="font-medium dark:text-white">{{
            item.action
          }}</span></template
        ><template #cell-actor_email="{ item }"
          ><span class="text-gray-500">{{
            item.actor_email || t("common.system")
          }}</span></template
        ><template #cell-auditable_type="{ item }"
          ><span class="text-gray-500">{{
            item.auditable_type
              ? `${item.auditable_type} #${item.auditable_id}`
              : "—"
          }}</span></template
        ><template #cell-ip_address="{ item }"
          ><span class="text-gray-500">{{
            item.ip_address || "—"
          }}</span></template
        ><template #cell-created_at="{ item }"
          ><span class="text-gray-500">{{
            new Date(item.created_at).toLocaleString()
          }}</span></template
        ></DataTable
      >
    </div>
  </AdminLayout>
</template>
