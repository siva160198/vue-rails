<script setup>
import { computed, reactive, ref } from "vue";
import { Save } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { apiFetch } from "../services/api";
import { confirmToast, toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import PermissionPicker from "../components/PermissionPicker.vue";
import DataTable from "../components/DataTable.vue";
import { hasChanges, snapshot } from "../services/changeTracking";
import { t } from "../services/i18n";
import { useAuth } from "../services/auth";
import { useServerTable } from "../services/serverTable";
import AppModal from "../components/AppModal.vue";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";
import TextareaInput from "../components/TextareaInput.vue";
import TableActionButton from "../components/TableActionButton.vue";
import { useFormErrors } from "../services/formErrors";
import StepUpPrompt from "../components/security/StepUpPrompt.vue";

const permissions = ref([]);
const creating = ref(false);
const savingRoleIds = ref(new Set());
const deletingRoleIds = ref(new Set());
const editingRole = ref(null);
const editSnapshot = ref(null);
const modalLoading = ref(false);
const createFormElement = ref(null);
const editFormElement = ref(null);
const createErrors = useFormErrors();
const editErrors = useFormErrors();
const pendingSecurityAction = ref(null);
let modalRequestSequence = 0;
const { can, canAny } = useAuth();
const {
  items: roles,
  loading,
  pagination,
  load: loadRoles,
  updateItem: updateRole,
  removeItem: removeRole,
} = useServerTable({
  endpoint: "/api/v1/admin/roles",
  collectionKey: "roles",
  onResponse: (response) => {
    permissions.value = response.permissions;
  },
});
const form = reactive({
  key: "",
  name: "",
  description: "",
  permission_keys: [],
});
const canCreateRole = () => can("roles.create");
const canUpdateRole = () => can("roles.update");
const canDeleteRole = () => can("roles.delete");
const hasRoleActions = () => canAny(["roles.update", "roles.delete"]);
const roleState = (role) => ({
  name: role.name,
  description: role.description || "",
  permission_keys: role.permission_keys,
});
const hasEditChanges = computed(
  () =>
    editingRole.value &&
    hasChanges(roleState(editingRole.value), editSnapshot.value),
);
const columns = computed(() => [
  { key: "name", label: t("roles.name") },
  { key: "key", label: t("roles.key") },
  { key: "description", label: t("roles.description") },
  { key: "permissions", label: t("roles.permissions"), sortable: false },
  { key: "users_count", label: t("roles.users") },
  { key: "action", label: t("common.action"), sortable: false },
]);

function sanitizeKey(event) {
  createErrors.clearError("key");
  form.key = event.target.value
    .toLowerCase()
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_]/g, "");
}

async function openEditModal(role) {
  editErrors.clearErrors();
  const requestSequence = ++modalRequestSequence;
  editingRole.value = { id: role.id, key: role.key, name: role.name };
  editSnapshot.value = null;
  modalLoading.value = true;
  try {
    const response = await apiFetch(`/api/v1/admin/roles/${role.id}`);
    if (requestSequence !== modalRequestSequence) return;
    editingRole.value = {
      ...response.role,
      permission_keys: [...response.role.permission_keys],
    };
    permissions.value = response.permissions;
    editSnapshot.value = snapshot(roleState(editingRole.value));
  } catch (requestError) {
    if (requestSequence !== modalRequestSequence) return;
    editingRole.value = null;
    toast.error(requestError.message);
  } finally {
    if (requestSequence === modalRequestSequence) modalLoading.value = false;
  }
}

function closeEditModal() {
  if (
    modalLoading.value ||
    (editingRole.value && savingRoleIds.value.has(editingRole.value.id))
  )
    return;
  modalRequestSequence += 1;
  editingRole.value = null;
  editSnapshot.value = null;
  editErrors.clearErrors();
}

async function createRole(stepUpToken = "") {
  if (creating.value || !canCreateRole()) return;
  const valid = await createErrors.validate({
    name: () => form.name.trim() ? "" : t("validation.required"),
    key: () => !form.key ? t("validation.required") : !/^[a-z0-9_]+$/.test(form.key) ? t("validation.role_key") : "",
  }, createFormElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  creating.value = true;
  createErrors.clearErrors();
  try {
    await apiFetch("/api/v1/admin/roles", {
      method: "POST",
      headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {},
      body: JSON.stringify(form),
    });
    Object.assign(form, {
      key: "",
      name: "",
      description: "",
      permission_keys: [],
    });
    toast.success(t("roles.created"));
    await loadRoles();
  } catch (requestError) {
    if (requestError.code === "STEP_UP_REQUIRED") { pendingSecurityAction.value = { type: "create" }; return; }
    await createErrors.applyApiError(requestError, createFormElement.value);
    toast.error(requestError.message);
  } finally {
    creating.value = false;
  }
}

async function saveRole(role, stepUpToken = "") {
  if (savingRoleIds.value.has(role.id) || !hasEditChanges.value) return;
  const valid = await editErrors.validate({ name: () => role.name.trim() ? "" : t("validation.required") }, editFormElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  savingRoleIds.value = new Set(savingRoleIds.value).add(role.id);
  editErrors.clearErrors();
  try {
    const response = await apiFetch(`/api/v1/admin/roles/${role.id}`, {
      method: "PATCH",
      headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {},
      body: JSON.stringify({
        name: role.name,
        description: role.description,
        permission_keys: role.permission_keys,
      }),
    });
    updateRole(role.id, response.role);
    toast.success(t("roles.updated", { name: role.name }));
    editingRole.value = null;
    editSnapshot.value = null;
  } catch (requestError) {
    if (requestError.code === "STEP_UP_REQUIRED") { pendingSecurityAction.value = { type: "update", role }; return; }
    await editErrors.applyApiError(requestError, editFormElement.value);
    toast.error(requestError.message);
  } finally {
    const nextIds = new Set(savingRoleIds.value);
    nextIds.delete(role.id);
    savingRoleIds.value = nextIds;
  }
}

async function deleteRole(role, stepUpToken = "", confirmed = false) {
  if (deletingRoleIds.value.has(role.id)) return;
  if (!confirmed &&
    !(await confirmToast(t("roles.confirm_delete", { name: role.name }), {
      confirmLabel: t("common.delete"),
    }))
  )
    return;
  deletingRoleIds.value = new Set(deletingRoleIds.value).add(role.id);
  try {
    await apiFetch(`/api/v1/admin/roles/${role.id}`, { method: "DELETE", headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {} });
    removeRole(role.id);
    toast.success(t("roles.deleted", { name: role.name }));
  } catch (requestError) {
    if (requestError.code === "STEP_UP_REQUIRED") { pendingSecurityAction.value = { type: "delete", role }; return; }
    toast.error(requestError.message);
  } finally {
    const nextIds = new Set(deletingRoleIds.value);
    nextIds.delete(role.id);
    deletingRoleIds.value = nextIds;
  }
}
async function finishSecurityAction(token) {
  const pending = pendingSecurityAction.value; pendingSecurityAction.value = null;
  if (pending.type === "create") await createRole(token);
  if (pending.type === "update") await saveRole(pending.role, token);
  if (pending.type === "delete") await deleteRole(pending.role, token, true);
}
</script>

<template>
  <AdminLayout>
    <div class="mx-auto max-w-[1536px]">
      <div class="mb-6">
        <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">
          {{ t("roles.title") }}
        </h1>
        <p class="mt-1 text-sm text-gray-500">{{ t("roles.subtitle") }}</p>
      </div>

      <form
        ref="createFormElement"
        v-if="canCreateRole()"
        novalidate
        class="mb-6 grid gap-4 rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03] md:grid-cols-2"
        @submit.prevent="createRole"
      >
        <FormField :label="t('roles.name')" :error="createErrors.errorFor('name')">
          <TextInput
            v-model="form.name"
            name="name"
            :disabled="creating"
            required
            class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white"
            :placeholder="t('roles.name_placeholder')"
            @input="createErrors.clearError('name')"
          />
        </FormField>
        <FormField :label="t('roles.key')" :help="t('roles.key_help')" :error="createErrors.errorFor('key')">
          <TextInput
            v-model="form.key"
            name="key"
            :disabled="creating"
            required
            pattern="[a-z0-9_]+"
            class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white"
            placeholder="editor"
            @input="sanitizeKey"
          />
        </FormField>
        <FormField class="md:col-span-2" :label="t('roles.description')" :error="createErrors.errorFor('description')">
          <TextareaInput
            v-model="form.description"
            name="description"
            :disabled="creating"
            rows="2"
            @input="createErrors.clearError('description')"
            class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white"
          />
        </FormField>
        <fieldset
          :disabled="creating"
          class="md:col-span-2 disabled:opacity-60"
        >
          <legend class="mb-3 text-sm font-medium dark:text-white">
            {{ t("roles.permissions") }}
          </legend>
          <PermissionPicker
            v-model="form.permission_keys"
            :permissions="permissions"
            :disabled="creating"
          />
        </fieldset>
        <div class="md:col-span-2">
          <AsyncButton
            type="submit"
            :loading="creating"
            :disabled="creating"
            :loading-text="t('roles.adding')"
            class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"
            >{{ t("roles.add") }}</AsyncButton
          >
        </div>
      </form>

      <DataTable
        :items="roles"
        :columns="columns"
        :loading="loading"
        :empty-text="t('roles.empty')"
        server-mode
        :total="pagination.total"
        @request="loadRoles"
        ><template #cell-name="{ item: role }"
          ><span class="font-medium text-gray-800 dark:text-white">{{
            role.name
          }}</span></template
        ><template #cell-key="{ item: role }"
          ><span class="font-mono text-xs text-gray-500">{{ role.key }}</span
          ><span
            v-if="role.system"
            class="ml-2 rounded-full bg-brand-50 px-2 py-1 text-[10px] text-brand-600"
            >{{ t("common.system") }}</span
          ></template
        ><template #cell-description="{ item: role }"
          ><p
            :title="role.description || t('roles.no_description')"
            class="max-w-sm line-clamp-2 text-sm text-gray-500"
          >
            {{ role.description || t("roles.no_description") }}
          </p></template
        ><template #cell-permissions="{ item: role }"
          ><span
            class="inline-flex rounded-full bg-brand-50 px-2.5 py-1 text-xs font-medium text-brand-600 dark:bg-brand-500/10 dark:text-brand-400"
            >{{
              t("roles.permission_count", {
                count: role.permission_keys.length,
              })
            }}</span
          ></template
        ><template #cell-users_count="{ item: role }"
          ><span class="text-gray-500">{{ role.users_count }}</span></template
        ><template #cell-action="{ item: role }"
          ><div v-if="hasRoleActions()" class="flex gap-2">
            <TableActionButton
              v-if="canUpdateRole()"
              action="edit"
              :label="t('common.edit')"
              :accessible-label="t('roles.edit_role', { name: role.name })"
              :disabled="deletingRoleIds.has(role.id)"
              @click="openEditModal(role)"
            />
            <TableActionButton
              v-if="canDeleteRole()"
              action="delete"
              :label="t('common.delete')"
              :accessible-label="t('roles.delete_role', { name: role.name })"
              :loading="deletingRoleIds.has(role.id)"
              :disabled="
                role.system ||
                role.users_count > 0 ||
                savingRoleIds.has(role.id)
              "
              :loading-text="t('common.deleting')"
              @click="deleteRole(role)"
            />
          </div>
          <span v-else class="text-xs text-gray-400">{{
            t("common.view_only")
          }}</span></template
        ></DataTable
      >
    </div>

    <AppModal
      :open="Boolean(editingRole)"
      :title="t('roles.edit_title')"
      :hint="editingRole ? t('roles.edit_hint', { key: editingRole.key }) : ''"
      :loading="modalLoading"
      :close-disabled="Boolean(editingRole && savingRoleIds.has(editingRole.id))"
      size="lg"
      @close="closeEditModal"
    >
      <form
        v-if="editingRole"
        ref="editFormElement"
        id="edit-role-form"
        novalidate
        class="space-y-5"
        @submit.prevent="saveRole(editingRole)"
      >
            <FormField :label="t('roles.name')" :error="editErrors.errorFor('name')">
              <TextInput
                v-model="editingRole.name"
                name="name"
                required
                :disabled="savingRoleIds.has(editingRole.id)"
                @input="editErrors.clearError('name')"
                class="w-full rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white"
              />
            </FormField>
            <FormField :label="t('roles.description')" :error="editErrors.errorFor('description')">
              <TextareaInput
                v-model="editingRole.description"
                name="description"
                rows="4"
                :disabled="savingRoleIds.has(editingRole.id)"
                :placeholder="t('roles.description_placeholder')"
                class="w-full resize-y rounded-lg border border-gray-200 bg-transparent px-4 py-2.5 text-sm disabled:opacity-60 dark:border-gray-700 dark:text-white"
                @input="editErrors.clearError('description')"
              />
            </FormField>
            <fieldset :disabled="savingRoleIds.has(editingRole.id)">
              <legend class="mb-3 text-sm font-medium dark:text-white">
                {{ t("roles.permissions") }}
              </legend>
              <PermissionPicker
                v-model="editingRole.permission_keys"
                :permissions="permissions"
                :readonly="editingRole.key === 'admin'"
              />
            </fieldset>
      </form>
      <template #footer>
            <button
              type="button"
              :disabled="savingRoleIds.has(editingRole.id)"
              class="rounded-lg border border-gray-200 px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:opacity-60 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800"
              @click="closeEditModal"
            >
              {{ t("common.cancel") }}
            </button>
            <AsyncButton
              form="edit-role-form"
              type="submit"
              :loading="savingRoleIds.has(editingRole.id)"
              :disabled="!hasEditChanges"
              :loading-text="t('common.saving')"
              class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"
            >
              <Save :size="16" />{{ t("common.save") }}
            </AsyncButton>
      </template>
    </AppModal>
    <AppModal :open="Boolean(pendingSecurityAction)" :title="t('security.additional_verification')" size="md" @close="pendingSecurityAction = null"><StepUpPrompt v-if="pendingSecurityAction" purpose="admin_role_change" @verified="finishSecurityAction" @cancel="pendingSecurityAction = null" /></AppModal>
  </AdminLayout>
</template>
