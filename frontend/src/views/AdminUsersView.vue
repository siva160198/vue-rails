<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { CheckCircle2, XCircle } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { apiFetch, currentUser } from "../services/api";
import { toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import { hasChanges, snapshot } from "../services/changeTracking";
import { t } from "../services/i18n";
import DataTable from "../components/DataTable.vue";
import SelectInput from "../components/SelectInput.vue";

const router = useRouter();
const admin = ref(null);
const users = ref([]);
const roles = ref([]);
const search = ref("");
const loading = ref(false);
const savingUserIds = ref(new Set());
const logoutLoading = ref(false);
const userSnapshots = ref(new Map());
const lastSearch = ref(null);
const totalUsers = ref(0);
const columns = computed(() => [
  { key: "email_address", label: "Email" },
  { key: "role", label: t("users.role") },
  { key: "active", label: t("common.status") },
  { key: "email_verified_at", label: t("users.verified") },
  { key: "action", label: t("common.action"), sortable: false },
]);
const canUpdate = () => admin.value?.permissions.includes("users.update");
const userState = (user) => ({ role: user.role, active: user.active });
const hasUserChanges = (user) =>
  hasChanges(userState(user), userSnapshots.value.get(user.id));

async function loadUsers(options = { page: 1, per_page: 10 }) {
  if (loading.value) return;
  loading.value = true;
  try {
    const query = new URLSearchParams(
      Object.entries(options).filter(([, value]) => value !== ""),
    ).toString();
    const response = await apiFetch(`/api/v1/admin/users?${query}`);
    users.value = response.users;
    roles.value = response.roles;
    totalUsers.value = response.pagination.total;
    userSnapshots.value = new Map(
      response.users.map((user) => [user.id, snapshot(userState(user))]),
    );
    lastSearch.value = search.value;
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    loading.value = false;
  }
}

async function saveUser(user) {
  if (savingUserIds.value.has(user.id) || !hasUserChanges(user)) return;
  savingUserIds.value = new Set(savingUserIds.value).add(user.id);
  try {
    const response = await apiFetch(`/api/v1/admin/users/${user.id}`, {
      method: "PATCH",
      body: JSON.stringify({ role: user.role, active: user.active }),
    });
    Object.assign(user, response.user);
    userSnapshots.value = new Map(userSnapshots.value).set(
      user.id,
      snapshot(userState(user)),
    );
    toast.success(t("users.updated", { email: user.email_address }));
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    const nextIds = new Set(savingUserIds.value);
    nextIds.delete(user.id);
    savingUserIds.value = nextIds;
  }
}

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

onMounted(async () => {
  try {
    admin.value = await currentUser();
  } catch (requestError) {
    toast.error(requestError.message);
  }
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
        :total="totalUsers"
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
          ><SelectInput
            v-model="user.role"
            :disabled="
              user.id === admin?.id ||
              !canUpdate() ||
              savingUserIds.has(user.id)
            "
            class="rounded-lg px-3 py-2"
          >
            <option v-for="role in roles" :key="role.key" :value="role.key">
              {{ role.name }}
            </option>
          </SelectInput></template
        ><template #cell-active="{ item: user }"
          ><label
            class="inline-flex items-center gap-3"
            :class="
              user.id === admin?.id ||
              !canUpdate() ||
              savingUserIds.has(user.id)
                ? 'cursor-not-allowed opacity-60'
                : 'cursor-pointer'
            "
            ><input
              v-model="user.active"
              type="checkbox"
              class="peer sr-only"
              :disabled="
                user.id === admin?.id ||
                !canUpdate() ||
                savingUserIds.has(user.id)
              "
            /><span
              class="relative h-6 w-11 rounded-full bg-gray-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-transform peer-checked:bg-brand-500 peer-checked:after:translate-x-5"
            ></span
            ><span>{{
              t(user.active ? "users.active" : "users.inactive")
            }}</span></label
          ></template
        ><template #cell-email_verified_at="{ item: user }"
          ><CheckCircle2
            v-if="user.email_verified_at"
            :size="22"
            class="text-brand-600" /><XCircle
            v-else
            :size="22"
            class="text-error-700" /></template
        ><template #cell-action="{ item: user }"
          ><AsyncButton
            v-if="canUpdate()"
            :loading="savingUserIds.has(user.id)"
            :disabled="user.id === admin?.id || !hasUserChanges(user)"
            :loading-text="t('common.saving')"
            class="rounded-lg bg-gray-900 px-4 py-2 text-xs font-semibold text-white"
            @click="saveUser(user)"
            >{{ t("common.save") }}</AsyncButton
          ><span v-else class="text-xs text-gray-400">{{
            t("common.view_only")
          }}</span></template
        ></DataTable
      >
    </div>
  </AdminLayout>
</template>
