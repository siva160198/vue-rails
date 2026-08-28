<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { apiFetch, currentUser } from "../services/api";
import { toast } from "../services/toast";
import { t } from "../services/i18n";
import DataTable from "../components/DataTable.vue";

const router = useRouter();
const admin = ref(null);
const logs = ref([]);
const logoutLoading = ref(false);
const loading = ref(false);
const totalLogs = ref(0);
const columns = computed(() => [
  { key: "action", label: t("audit.action") },
  { key: "actor_email", label: t("audit.actor") },
  { key: "auditable_type", label: t("audit.target") },
  { key: "ip_address", label: "IP" },
  { key: "created_at", label: t("audit.time") },
]);

async function logout() {
  if (logoutLoading.value) return;
  logoutLoading.value = true;
  try {
    await apiFetch("/api/v1/session", { method: "DELETE" });
    await router.push("/login");
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    logoutLoading.value = false;
  }
}

async function loadLogs(options = { page: 1, per_page: 10 }) {
  if (loading.value) return;
  loading.value = true;
  try {
    const query = new URLSearchParams(Object.entries(options).filter(([, value]) => value !== "")).toString();
    const response = await apiFetch(`/api/v1/admin/audit_logs?${query}`);
    logs.value = response.audit_logs;
    totalLogs.value = response.pagination.total;
  } catch (requestError) {
    toast.error(requestError.message);
  } finally { loading.value = false; }
}

onMounted(async () => {
  try { admin.value = await currentUser(); }
  catch (requestError) { toast.error(requestError.message); }
});
</script>

<template>
  <AdminLayout
    :email="admin?.email_address"
    :permissions="admin?.permissions"
    :logout-loading="logoutLoading"
    @logout="logout"
  >
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
        :total="totalLogs"
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
