<script setup>
import { computed, ref } from "vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import AppModal from "../components/AppModal.vue";
import DataTable from "../components/DataTable.vue";
import StepUpPrompt from "../components/security/StepUpPrompt.vue";
import TableActionButton from "../components/TableActionButton.vue";
import { apiFetch } from "../services/api";
import { useAuth } from "../services/auth";
import { locale, t } from "../services/i18n";
import { useServerTable } from "../services/serverTable";
import { toast } from "../services/toast";

const selected = ref(null);
const { can } = useAuth();
const { items, loading, pagination, load, removeItem } = useServerTable({ endpoint: "/api/v1/admin/approvals", collectionKey: "approvals" });
const columns = computed(() => [
  { key: "action_key", label: t("approvals.action") }, { key: "requester_email", label: t("approvals.requester") },
  { key: "created_at", label: t("approvals.requested_at") }, { key: "expires_at", label: t("approvals.expires_at") },
  { key: "action", label: t("common.action"), sortable: false },
]);
async function approve(token) {
  try { await apiFetch(`/api/v1/admin/approvals/${selected.value.id}`, { method: "PATCH", headers: { "X-Step-Up-Token": token } }); removeItem(selected.value.id); selected.value = null; toast.success(t("approvals.approved")); }
  catch (error) { toast.error(error.message); }
}
</script>
<template><AdminLayout><div class="mx-auto max-w-[1536px]"><header class="mb-6"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t('approvals.title') }}</h1><p class="mt-1 text-sm text-gray-500">{{ t('approvals.subtitle') }}</p></header><DataTable :items="items" :columns="columns" :loading="loading" :empty-text="t('approvals.empty')" server-mode :total="pagination.total" @request="load"><template #cell-created_at="{ item }"><span class="text-gray-500">{{ new Date(item.created_at).toLocaleString(locale) }}</span></template><template #cell-expires_at="{ item }"><span class="text-gray-500">{{ new Date(item.expires_at).toLocaleString(locale) }}</span></template><template #cell-action="{ item }"><TableActionButton v-if="can('security_approvals.update')" action="edit" :label="t('approvals.review')" @click="selected = item" /></template></DataTable></div><AppModal :open="Boolean(selected)" :title="t('approvals.review')" :hint="selected?.requester_email" size="md" @close="selected = null"><div v-if="selected" class="mb-4 rounded-xl bg-gray-50 p-4 text-sm dark:bg-gray-800"><p class="font-medium dark:text-white">{{ selected.action_key }}</p><pre class="mt-2 overflow-auto whitespace-pre-wrap text-xs text-gray-500">{{ JSON.stringify(selected.payload_summary, null, 2) }}</pre></div><StepUpPrompt v-if="selected" purpose="admin_approval" @verified="approve" @cancel="selected = null" /></AppModal></AdminLayout></template>
