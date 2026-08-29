import { computed, ref } from "vue";
import { apiFetch, currentUser } from "./api";

const user = ref(null);
const resolved = ref(false);
const loading = ref(false);
const logoutLoading = ref(false);
let pendingRequest;

export function useAuth() {
  const permissions = computed(() => user.value?.permissions || []);

  function setUser(value) {
    user.value = value || null;
    resolved.value = true;
  }

  function clearUser() {
    user.value = null;
    resolved.value = true;
  }

  async function loadUser({ force = false } = {}) {
    if (resolved.value && !force) return user.value;
    if (pendingRequest) return pendingRequest;

    loading.value = true;
    pendingRequest = currentUser()
      .then((value) => {
        setUser(value);
        return user.value;
      })
      .finally(() => {
        loading.value = false;
        pendingRequest = undefined;
      });
    return pendingRequest;
  }

  async function logout() {
    if (logoutLoading.value) return;
    logoutLoading.value = true;
    try {
      await apiFetch("/api/v1/session", { method: "DELETE" });
      clearUser();
    } finally {
      logoutLoading.value = false;
    }
  }

  const can = (permission) => permissions.value.includes(permission);
  const canAny = (requested) => requested.some(can);

  return {
    user,
    permissions,
    resolved,
    loading,
    logoutLoading,
    loadUser,
    setUser,
    clearUser,
    logout,
    can,
    canAny,
  };
}

export function resetAuthState() {
  user.value = null;
  resolved.value = false;
  loading.value = false;
  logoutLoading.value = false;
  pendingRequest = undefined;
}
