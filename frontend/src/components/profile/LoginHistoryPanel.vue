<script setup>
import { computed } from "vue";
import DataTable from "../DataTable.vue";
import { locale, t } from "../../services/i18n";
import { useServerTable } from "../../services/serverTable";

const { items, loading, pagination, load } = useServerTable({ endpoint: "/api/v1/account_security", collectionKey: "events" });
const columns = computed(() => [
  { key: "action", label: t("security.event") },
  { key: "ip_address", label: "IP" },
  { key: "user_agent", label: t("sessions.device") },
  { key: "created_at", label: t("security.time") },
]);
</script>

<template><DataTable :items="items" :columns="columns" :loading="loading" :empty-text="t('security.empty_history')" server-mode :total="pagination.total" @request="load"><template #cell-created_at="{ item }"><span class="text-gray-500">{{ new Date(item.created_at).toLocaleString(locale) }}</span></template><template #cell-ip_address="{ item }"><span class="text-gray-500">{{ item.ip_address || '—' }}</span></template><template #cell-user_agent="{ item }"><span class="line-clamp-2 text-gray-500" :title="item.user_agent">{{ item.user_agent || t('sessions.unknown_device') }}</span></template></DataTable></template>
