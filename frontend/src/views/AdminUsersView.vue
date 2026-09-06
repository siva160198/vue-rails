<script setup>
import { computed, ref } from "vue";
import { CheckCircle2, Plus, Save, XCircle } from "@lucide/vue";
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
import TextInput from "../components/TextInput.vue";

const roles = ref([]);
const savingUserIds = ref(new Set());
const editingUser = ref(null);
const editSnapshot = ref(null);
const modalLoading = ref(false);
const editFormElement = ref(null);
const editErrors = useFormErrors();
const pendingSecureUser = ref(null);
const createOpen = ref(false);
const createLoading = ref(false);
const creating = ref(false);
const createFormElement = ref(null);
const createErrors = useFormErrors();
const pendingSecureCreate = ref(false);
const newUser = ref(null);
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
  { key: "login_otp_required", label: t("users.login_otp") },
  { key: "email_verified_at", label: t("users.verified") },
  { key: "action", label: t("common.action"), sortable: false },
]);
const canUpdate = () => can("users.update");
const userState = (user) => ({ role: user.role, active: user.active, login_otp_required: user.login_otp_required });
const hasUserChanges = computed(
  () =>
    editingUser.value &&
    hasChanges(userState(editingUser.value), editSnapshot.value),
);
const roleName = (key) =>
  roles.value.find((role) => role.key === key)?.name || key;
const roleRequiresOtp = (key) => Boolean(roles.value.find((role) => role.key === key)?.login_otp_required);

function normalizeOtpForRole(target) {
  if (roleRequiresOtp(target.role)) target.login_otp_required = true;
}

async function openCreateModal() {
  createErrors.clearErrors();
  createOpen.value = true;
  createLoading.value = true;
  try {
    const response = await apiFetch("/api/v1/admin/users/new");
    roles.value = response.roles;
    newUser.value = {
      email_address: "",
      first_name: "",
      last_name: "",
      phone: "",
      role: roles.value.some((role) => role.key === "member") ? "member" : roles.value[0]?.key || "",
      active: true,
      login_otp_required: true,
    };
    normalizeOtpForRole(newUser.value);
  } catch (requestError) {
    createOpen.value = false;
    toast.error(requestError.message);
  } finally {
    createLoading.value = false;
  }
}

function closeCreateModal(force = false) {
  if (!force && (createLoading.value || creating.value)) return;
  createOpen.value = false;
  newUser.value = null;
  createErrors.clearErrors();
}

async function createUser(stepUpToken = "") {
  if (creating.value || !newUser.value) return;
  const valid = await createErrors.validate({
    email_address: () => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newUser.value.email_address) ? "" : t("validation.email"),
    role: () => newUser.value.role ? "" : t("validation.required"),
    phone: () => !newUser.value.phone || /^[+0-9() .-]+$/.test(newUser.value.phone) ? "" : t("validation.phone"),
  }, createFormElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }

  creating.value = true;
  try {
    await apiFetch("/api/v1/admin/users", {
      method: "POST",
      headers: stepUpToken ? { "X-Step-Up-Token": stepUpToken } : {},
      body: JSON.stringify(newUser.value),
    });
    const email = newUser.value.email_address;
    closeCreateModal(true);
    await loadUsers();
    toast.success(t("users.created", { email }));
  } catch (requestError) {
    if (requestError.code === "STEP_UP_REQUIRED") { pendingSecureCreate.value = true; return; }
    await createErrors.applyApiError(requestError, createFormElement.value);
    toast.error(requestError.message);
  } finally {
    creating.value = false;
  }
}

async function finishSecureCreate(token) {
  pendingSecureCreate.value = false;
  await createUser(token);
}

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
      body: JSON.stringify({ role: user.role, active: user.active, login_otp_required: user.login_otp_required }),
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
      <div class="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">
            {{ t("users.title") }}
          </h1>
          <p class="mt-1 text-sm text-gray-500">{{ t("users.subtitle") }}</p>
        </div>
        <AsyncButton
          v-if="can('users.create')"
          class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"
          @click="openCreateModal"
        ><Plus :size="17" />{{ t("users.add") }}</AsyncButton>
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
        ><template #cell-login_otp_required="{ item: user }"
          ><span :title="t(user.login_otp_required ? 'users.otp_enabled' : 'users.otp_disabled')">
            <CheckCircle2 v-if="user.login_otp_required" :size="22" class="text-brand-600" />
            <XCircle v-else :size="22" class="text-gray-400" />
          </span></template
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
                @change="normalizeOtpForRole(editingUser); editErrors.clearError('role')"
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
            <ToggleInput
              v-model="editingUser.login_otp_required"
              :label="t('users.login_otp')"
              :hint="roleRequiresOtp(editingUser.role) ? t('users.otp_required_role_hint') : t('users.otp_hint')"
              :disabled="savingUserIds.has(editingUser.id) || roleRequiresOtp(editingUser.role)"
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
    <AppModal
      :open="createOpen"
      :title="t('users.add')"
      :hint="t('users.add_hint')"
      :loading="createLoading"
      :close-disabled="creating"
      size="md"
      @close="closeCreateModal"
    >
      <form v-if="newUser" ref="createFormElement" id="create-user-form" novalidate class="space-y-5" @submit.prevent="createUser()">
        <div class="grid gap-5 sm:grid-cols-2">
          <FormField :label="t('profile.first_name')" :error="createErrors.errorFor('first_name')">
            <TextInput v-model="newUser.first_name" name="first_name" maxlength="80" :disabled="creating" @input="createErrors.clearError('first_name')" />
          </FormField>
          <FormField :label="t('profile.last_name')" :error="createErrors.errorFor('last_name')">
            <TextInput v-model="newUser.last_name" name="last_name" maxlength="80" :disabled="creating" @input="createErrors.clearError('last_name')" />
          </FormField>
        </div>
        <FormField label="Email" :error="createErrors.errorFor('email_address')">
          <TextInput v-model="newUser.email_address" name="email_address" type="email" autocomplete="off" required :disabled="creating" @input="createErrors.clearError('email_address')" />
        </FormField>
        <FormField :label="t('profile.phone')" :error="createErrors.errorFor('phone')">
          <TextInput v-model="newUser.phone" name="phone" type="tel" maxlength="30" :disabled="creating" @input="createErrors.clearError('phone')" />
        </FormField>
        <FormField :label="t('users.role')" :error="createErrors.errorFor('role')">
          <SelectInput v-model="newUser.role" name="role" :disabled="creating" @change="normalizeOtpForRole(newUser); createErrors.clearError('role')">
            <option v-for="role in roles" :key="role.key" :value="role.key">{{ role.name }}</option>
          </SelectInput>
        </FormField>
        <ToggleInput v-model="newUser.active" :label="t('users.account_status')" :hint="t('users.account_status_hint')" :disabled="creating" />
        <ToggleInput v-model="newUser.login_otp_required" :label="t('users.login_otp')" :hint="roleRequiresOtp(newUser.role) ? t('users.otp_required_role_hint') : t('users.otp_hint')" :disabled="creating || roleRequiresOtp(newUser.role)" />
      </form>
      <template #footer>
        <button type="button" :disabled="creating" class="rounded-lg border border-gray-200 px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:opacity-60 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800" @click="closeCreateModal()">{{ t("common.cancel") }}</button>
        <AsyncButton form="create-user-form" type="submit" :loading="creating" :loading-text="t('users.adding')" class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"><Plus :size="16" />{{ t("users.add") }}</AsyncButton>
      </template>
    </AppModal>
    <AppModal :open="Boolean(pendingSecureUser)" :title="t('security.additional_verification')" size="md" @close="pendingSecureUser = null"><StepUpPrompt v-if="pendingSecureUser" purpose="admin_user_update" @verified="finishSecureUser" @cancel="pendingSecureUser = null" /></AppModal>
    <AppModal :open="pendingSecureCreate" :title="t('security.additional_verification')" size="md" @close="pendingSecureCreate = false"><StepUpPrompt v-if="pendingSecureCreate" purpose="admin_user_create" @verified="finishSecureCreate" @cancel="pendingSecureCreate = false" /></AppModal>
  </AdminLayout>
</template>
