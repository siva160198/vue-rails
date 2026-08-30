<script setup>
import { computed, ref } from "vue";
import { LogOut } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import AsyncButton from "../components/AsyncButton.vue";
import DataTable from "../components/DataTable.vue";
import TableActionButton from "../components/TableActionButton.vue";
import { apiFetch } from "../services/api";
import { locale, t } from "../services/i18n";
import { useServerTable } from "../services/serverTable";
import { confirmToast, toast } from "../services/toast";
import StepUpPrompt from "../components/security/StepUpPrompt.vue";

defineProps({ embedded: { type: Boolean, default: false } });

const revokingIds = ref(new Set());
const revokingOthers = ref(false);
const pendingRevokeOthers = ref(false);
const { items: sessions, loading, pagination, load, removeItem } = useServerTable({
  endpoint: "/api/v1/sessions",
  collectionKey: "sessions",
});
const columns = computed(() => [
  { key: "user_agent", label: t("sessions.device") },
  { key: "ip_address", label: "IP" },
  { key: "created_at", label: t("sessions.login_time") },
  { key: "last_seen_at", label: t("sessions.last_seen") },
  { key: "expires_at", label: t("sessions.expires_at") },
  { key: "action", label: t("common.action"), sortable: false },
]);
const otherCount = computed(() => sessions.value.filter((session) => !session.current).length);

async function revoke(session) {
  if (revokingIds.value.has(session.id)) return;
  if (!(await confirmToast(t("sessions.confirm_revoke"), { confirmLabel: t("sessions.revoke") }))) return;
  revokingIds.value = new Set(revokingIds.value).add(session.id);
  try {
    await apiFetch(`/api/v1/sessions/${session.id}`, { method: "DELETE" });
    removeItem(session.id);
    toast.success(t("sessions.revoked"));
  } catch (error) {
    toast.error(error.message);
  } finally {
    const next = new Set(revokingIds.value);
    next.delete(session.id);
    revokingIds.value = next;
  }
}

async function revokeOthers(stepUpToken = "", confirmed = false) {
  if (revokingOthers.value || otherCount.value === 0) return;
  if (!confirmed && !(await confirmToast(t("sessions.confirm_revoke_others"), { confirmLabel: t("sessions.revoke_others") }))) return;
  revokingOthers.value = true;
  try {
    await apiFetch("/api/v1/sessions/others", { method: "DELETE", headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {} });
    toast.success(t("sessions.others_revoked"));
    await load();
  } catch (error) {
    if (error.code === "STEP_UP_REQUIRED") { pendingRevokeOthers.value = true; return; }
    toast.error(error.message);
  } finally {
    revokingOthers.value = false;
  }
}
async function finishRevokeOthers(token) { pendingRevokeOthers.value = false; await revokeOthers(token, true); }

</script>

<template>
  <component :is="embedded ? 'div' : AdminLayout">
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t("sessions.title") }}</h1>
          <p class="mt-1 text-sm text-gray-500">{{ t("sessions.subtitle") }}</p>
        </div>
        <AsyncButton
          :loading="revokingOthers"
          :disabled="otherCount === 0"
          :loading-text="t('sessions.revoking')"
          class="rounded-lg border border-error-200 px-4 py-2.5 text-sm font-semibold text-error-700 hover:bg-error-50"
          @click="revokeOthers"
        ><LogOut :size="16" />{{ t("sessions.revoke_others") }}</AsyncButton>
      </div>
      <StepUpPrompt v-if="pendingRevokeOthers" class="mb-5" purpose="sessions_revoke" @verified="finishRevokeOthers" @cancel="pendingRevokeOthers = false" />
      <DataTable :items="sessions" :columns="columns" :loading="loading" :empty-text="t('sessions.empty')" server-mode :total="pagination.total" @request="load">
        <template #cell-user_agent="{ item }">
          <div class="max-w-xl"><span class="font-medium text-gray-800 dark:text-white">{{ item.user_agent || t("sessions.unknown_device") }}</span><span v-if="item.current" class="ml-2 rounded-full bg-brand-50 px-2 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10 dark:text-brand-400">{{ t("sessions.current") }}</span></div>
        </template>
        <template #cell-ip_address="{ item }"><span class="text-gray-500">{{ item.ip_address || "—" }}</span></template>
        <template #cell-created_at="{ item }"><span class="text-gray-500">{{ new Date(item.created_at).toLocaleString(locale) }}</span></template>
        <template #cell-last_seen_at="{ item }"><span class="text-gray-500">{{ new Date(item.last_seen_at).toLocaleString(locale) }}</span></template>
        <template #cell-expires_at="{ item }"><span class="text-gray-500">{{ new Date(item.expires_at).toLocaleString(locale) }}</span></template>
        <template #cell-action="{ item }">
          <span v-if="item.current" class="text-xs text-gray-400">{{ t("sessions.use_sign_out") }}</span>
          <TableActionButton v-else action="delete" :label="t('sessions.revoke')" :accessible-label="t('sessions.revoke_device', { device: item.user_agent || t('sessions.unknown_device') })" :loading="revokingIds.has(item.id)" :loading-text="t('sessions.revoking')" @click="revoke(item)" />
        </template>
      </DataTable>
    </div>
  </component>
</template>
