<script setup>
import { computed, ref } from "vue";
import { LogOut } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import AsyncButton from "../components/AsyncButton.vue";
import DataTable from "../components/DataTable.vue";
import TableActionButton from "../components/TableActionButton.vue";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";
import FileInput from "../components/FileInput.vue";
import { useAuth } from "../services/auth";
import { apiFetch } from "../services/api";
import { locale, t } from "../services/i18n";
import { useServerTable } from "../services/serverTable";
import { confirmToast, toast } from "../services/toast";

const revokingIds = ref(new Set());
const revokingOthers = ref(false);
const recoveryPassword = ref("");
const recoveryCodes = ref([]);
const generatingCodes = ref(false);
const avatar = ref(null);
const avatarAction = ref("");
const { user, setUser } = useAuth();
const { items: sessions, loading, pagination, load, removeItem } = useServerTable({
  endpoint: "/api/v1/sessions",
  collectionKey: "sessions",
});
const columns = computed(() => [
  { key: "user_agent", label: t("sessions.device") },
  { key: "ip_address", label: "IP" },
  { key: "created_at", label: t("sessions.login_time") },
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

async function revokeOthers() {
  if (revokingOthers.value || otherCount.value === 0) return;
  if (!(await confirmToast(t("sessions.confirm_revoke_others"), { confirmLabel: t("sessions.revoke_others") }))) return;
  revokingOthers.value = true;
  try {
    await apiFetch("/api/v1/sessions/others", { method: "DELETE" });
    toast.success(t("sessions.others_revoked"));
    await load();
  } catch (error) {
    toast.error(error.message);
  } finally {
    revokingOthers.value = false;
  }
}

async function generateRecoveryCodes() {
  if (generatingCodes.value || !recoveryPassword.value) return;
  generatingCodes.value = true;
  try {
    const payload = await apiFetch("/api/v1/profile/recovery_codes", { method: "POST", body: JSON.stringify({ password: recoveryPassword.value }) });
    recoveryCodes.value = payload.recovery_codes;
    recoveryPassword.value = "";
    toast.success(t("sessions.recovery_generated"));
  } catch (error) {
    toast.error(error.message);
  } finally {
    generatingCodes.value = false;
  }
}

async function uploadAvatar() {
  if (!avatar.value || avatarAction.value) return;
  avatarAction.value = "upload";
  try {
    const body = new FormData(); body.append("avatar", avatar.value);
    const payload = await apiFetch("/api/v1/profile", { method: "PATCH", body });
    setUser({ ...user.value, avatar_url: payload.avatar_url });
    avatar.value = null;
    toast.success(t("profile.avatar_updated"));
  } catch (error) { toast.error(error.message); } finally { avatarAction.value = ""; }
}

async function removeAvatar() {
  if (!user.value?.avatar_url || avatarAction.value) return;
  avatarAction.value = "remove";
  try {
    await apiFetch("/api/v1/profile", { method: "DELETE" });
    setUser({ ...user.value, avatar_url: null });
    toast.success(t("profile.avatar_removed"));
  } catch (error) { toast.error(error.message); } finally { avatarAction.value = ""; }
}
</script>

<template>
  <AdminLayout>
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
      <DataTable :items="sessions" :columns="columns" :loading="loading" :empty-text="t('sessions.empty')" server-mode :total="pagination.total" @request="load">
        <template #cell-user_agent="{ item }">
          <div class="max-w-xl"><span class="font-medium text-gray-800 dark:text-white">{{ item.user_agent || t("sessions.unknown_device") }}</span><span v-if="item.current" class="ml-2 rounded-full bg-brand-50 px-2 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10 dark:text-brand-400">{{ t("sessions.current") }}</span></div>
        </template>
        <template #cell-ip_address="{ item }"><span class="text-gray-500">{{ item.ip_address || "—" }}</span></template>
        <template #cell-created_at="{ item }"><span class="text-gray-500">{{ new Date(item.created_at).toLocaleString(locale) }}</span></template>
        <template #cell-action="{ item }">
          <span v-if="item.current" class="text-xs text-gray-400">{{ t("sessions.use_sign_out") }}</span>
          <TableActionButton v-else action="delete" :label="t('sessions.revoke')" :accessible-label="t('sessions.revoke_device', { device: item.user_agent || t('sessions.unknown_device') })" :loading="revokingIds.has(item.id)" :loading-text="t('sessions.revoking')" @click="revoke(item)" />
        </template>
      </DataTable>
      <section class="mt-6 rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t("sessions.recovery_title") }}</h2>
        <p class="mt-1 text-sm text-gray-500">{{ t("sessions.recovery_hint") }}</p>
        <form class="mt-5 flex max-w-xl flex-col gap-3 sm:flex-row sm:items-end" @submit.prevent="generateRecoveryCodes">
          <FormField class="flex-1" :label="t('auth.password')"><TextInput v-model="recoveryPassword" type="password" autocomplete="current-password" :disabled="generatingCodes" required /></FormField>
          <AsyncButton type="submit" :loading="generatingCodes" :disabled="!recoveryPassword" :loading-text="t('sessions.recovery_generating')" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-600">{{ t("sessions.recovery_generate") }}</AsyncButton>
        </form>
        <div v-if="recoveryCodes.length" class="mt-5 rounded-lg border border-brand-200 bg-brand-50 p-4"><p class="text-sm font-medium text-brand-700">{{ t("sessions.recovery_once") }}</p><div class="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4"><code v-for="item in recoveryCodes" :key="item" class="rounded bg-white px-3 py-2 text-center text-sm text-gray-800">{{ item }}</code></div></div>
      </section>
      <section class="mt-6 rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t("profile.avatar_title") }}</h2><p class="mt-1 text-sm text-gray-500">{{ t("profile.avatar_hint") }}</p>
        <form class="mt-5 flex max-w-2xl flex-col gap-3 sm:flex-row sm:items-end" @submit.prevent="uploadAvatar"><FormField class="flex-1" :label="t('profile.avatar_file')"><FileInput accept="image/jpeg,image/png,image/webp" :disabled="Boolean(avatarAction)" @change="avatar = $event.target.files[0] || null" /></FormField><AsyncButton type="submit" :loading="avatarAction === 'upload'" :disabled="!avatar || Boolean(avatarAction)" :loading-text="t('profile.uploading')" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-600">{{ t("profile.upload") }}</AsyncButton><AsyncButton type="button" :loading="avatarAction === 'remove'" :disabled="!user?.avatar_url || Boolean(avatarAction)" :loading-text="t('common.deleting')" class="rounded-lg border border-error-200 px-4 py-2.5 text-sm font-semibold text-error-700 hover:bg-error-50" @click="removeAvatar">{{ t("profile.remove") }}</AsyncButton></form>
      </section>
    </div>
  </AdminLayout>
</template>
