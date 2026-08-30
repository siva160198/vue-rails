<script setup>
import { computed, ref } from "vue";
import { CheckCircle2, Save, XCircle } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { apiFetch } from "../services/api";
import { toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import { hasChanges, snapshot } from "../services/changeTracking";
import { t } from "../services/i18n";
import DataTable from "../components/DataTable.vue";
import SelectInput from "../components/SelectInput.vue";
import { useAuth } from "../services/auth";
import { useServerTable } from "../services/serverTable";
import AppModal from "../components/AppModal.vue";
import FormField from "../components/FormField.vue";
import ToggleInput from "../components/ToggleInput.vue";
import TableActionButton from "../components/TableActionButton.vue";
import { useFormErrors } from "../services/formErrors";
import StepUpPrompt from "../components/security/StepUpPrompt.vue";

const roles = ref([]);
const savingUserIds = ref(new Set());
const editingUser = ref(null);
const editSnapshot = ref(null);
const modalLoading = ref(false);
const editFormElement = ref(null);
const editErrors = useFormErrors();
const pendingSecureUser = ref(null);
let modalRequestSequence = 0;
const { user: admin, can } = useAuth();
const {
  items: users,
  loading,
  pagination,
  load: loadUsers,
  updateItem: updateUser,
} = useServerTable({
  endpoint: "/api/v1/admin/users",
  collectionKey: "users",
  onResponse: (response) => {
    roles.value = response.roles;
  },
});
const columns = computed(() => [
  { key: "email_address", label: "Email" },
  { key: "role", label: t("users.role") },
  { key: "active", label: t("common.status") },
  { key: "email_verified_at", label: t("users.verified") },
  { key: "action", label: t("common.action"), sortable: false },
]);
const canUpdate = () => can("users.update");
const userState = (user) => ({ role: user.role, active: user.active });
const hasUserChanges = computed(
  () =>
    editingUser.value &&
    hasChanges(userState(editingUser.value), editSnapshot.value),
);
const roleName = (key) =>
  roles.value.find((role) => role.key === key)?.name || key;

async function openEditModal(user) {
  editErrors.clearErrors();
  const requestSequence = ++modalRequestSequence;
  editingUser.value = { id: user.id, email_address: user.email_address };
  editSnapshot.value = null;
  modalLoading.value = true;
  try {
    const response = await apiFetch(`/api/v1/admin/users/${user.id}`);
    if (requestSequence !== modalRequestSequence) return;
    editingUser.value = response.user;
    roles.value = response.roles;
    editSnapshot.value = snapshot(userState(editingUser.value));
  } catch (requestError) {
    if (requestSequence !== modalRequestSequence) return;
    editingUser.value = null;
    toast.error(requestError.message);
  } finally {
    if (requestSequence === modalRequestSequence) modalLoading.value = false;
  }
}

function closeEditModal() {
  if (
    modalLoading.value ||
    (editingUser.value && savingUserIds.value.has(editingUser.value.id))
  )
    return;
  modalRequestSequence += 1;
  editingUser.value = null;
  editSnapshot.value = null;
}

async function saveUser(user, stepUpToken = "") {
  if (savingUserIds.value.has(user.id) || !hasUserChanges.value) return;
  const valid = await editErrors.validate({ role: () => user.role ? "" : t("validation.required") }, editFormElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  savingUserIds.value = new Set(savingUserIds.value).add(user.id);
  try {
    const response = await apiFetch(`/api/v1/admin/users/${user.id}`, {
      method: "PATCH",
      headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {},
      body: JSON.stringify({ role: user.role, active: user.active }),
    });
    updateUser(user.id, response.user);
    toast.success(t("users.updated", { email: user.email_address }));
    editingUser.value = null;
    editSnapshot.value = null;
  } catch (requestError) {
    if (requestError.code === "STEP_UP_REQUIRED") { pendingSecureUser.value = user; return; }
    await editErrors.applyApiError(requestError, editFormElement.value); toast.error(requestError.message);
  } finally {
    const nextIds = new Set(savingUserIds.value);
    nextIds.delete(user.id);
    savingUserIds.value = nextIds;
  }
}
async function finishSecureUser(token) { const target = pendingSecureUser.value; pendingSecureUser.value = null; await saveUser(target, token); }
</script>

<template>
  <AdminLayout>
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6">
        <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">
          {{ t("users.title") }}
        </h1>
        <p class="mt-1 text-sm text-gray-500">{{ t("users.subtitle") }}</p>
      </div>
      <DataTable
        :items="users"
        :columns="columns"
        :loading="loading"
        :empty-text="t('users.empty')"
        server-mode
        cursor-mode
        :total="pagination.total"
        :next-cursor="pagination.next_cursor || ''"
        :previous-cursor="pagination.previous_cursor || ''"
        :has-next="pagination.has_next"
        :has-previous="pagination.has_previous"
        @request="loadUsers"
        ><template #cell-email_address="{ item: user }"
          ><span class="font-medium dark:text-white">{{
            user.email_address
          }}</span
          ><span
            v-if="user.id === admin?.id"
            class="ml-2 text-xs text-brand-500"
            >{{ t("users.you") }}</span
          ></template
        ><template #cell-role="{ item: user }"
          ><span class="text-gray-600 dark:text-gray-300">{{
            roleName(user.role)
          }}</span></template
        ><template #cell-active="{ item: user }"
          ><span
            class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium"
            :class="
              user.active
                ? 'bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400'
                : 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300'
            "
          >
            <span
              class="h-1.5 w-1.5 rounded-full"
              :class="user.active ? 'bg-brand-500' : 'bg-gray-400'"
            ></span>
            {{ t(user.active ? "users.active" : "users.inactive") }}
          </span></template
        ><template #cell-email_verified_at="{ item: user }"
          ><CheckCircle2
            v-if="user.email_verified_at"
            :size="22"
            class="text-brand-600" /><XCircle
            v-else
            :size="22"
            class="text-error-700" /></template
        ><template #cell-action="{ item: user }"
          ><TableActionButton
            v-if="canUpdate()"
            action="edit"
            :label="t('common.edit')"
            :accessible-label="t('users.edit_user', { email: user.email_address })"
            :disabled="user.id === admin?.id"
            @click="openEditModal(user)"
          /><span v-else class="text-xs text-gray-400">{{
            t("common.view_only")
          }}</span></template
        ></DataTable
      >
    </div>

    <AppModal
      :open="Boolean(editingUser)"
      :title="t('users.edit_title')"
      :hint="editingUser?.email_address"
      :loading="modalLoading"
      :close-disabled="Boolean(editingUser && savingUserIds.has(editingUser.id))"
      size="md"
      @close="closeEditModal"
    >
      <form
        v-if="editingUser"
        ref="editFormElement"
        id="edit-user-form"
        novalidate
        class="space-y-5"
        @submit.prevent="saveUser(editingUser)"
      >
            <FormField :label="t('users.role')" :error="editErrors.errorFor('role')">
              <SelectInput
                v-model="editingUser.role"
                name="role"
                :disabled="savingUserIds.has(editingUser.id)"
                @change="editErrors.clearError('role')"
              >
                <option v-for="role in roles" :key="role.key" :value="role.key">
                  {{ role.name }}
                </option>
              </SelectInput>
            </FormField>
            <ToggleInput
              v-model="editingUser.active"
              :label="t('users.account_status')"
              :hint="t('users.account_status_hint')"
              :disabled="savingUserIds.has(editingUser.id)"
            />
      </form>
      <template #footer>
            <button
              type="button"
              :disabled="editingUser && savingUserIds.has(editingUser.id)"
              class="rounded-lg border border-gray-200 px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:opacity-60 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800"
              @click="closeEditModal"
            >
              {{ t("common.cancel") }}
            </button>
            <AsyncButton
              form="edit-user-form"
              type="submit"
              :loading="Boolean(editingUser && savingUserIds.has(editingUser.id))"
              :disabled="!hasUserChanges"
              :loading-text="t('common.saving')"
              class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"
            >
              <Save :size="16" />{{ t("common.save") }}
            </AsyncButton>
      </template>
    </AppModal>
    <AppModal :open="Boolean(pendingSecureUser)" :title="t('security.additional_verification')" size="md" @close="pendingSecureUser = null"><StepUpPrompt v-if="pendingSecureUser" purpose="admin_user_update" @verified="finishSecureUser" @cancel="pendingSecureUser = null" /></AppModal>
  </AdminLayout>
</template>
