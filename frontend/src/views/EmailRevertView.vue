<script setup>
import { onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { apiFetch } from "../services/api";
import { t } from "../services/i18n";
import { toast } from "../services/toast";
import { useAuth } from "../services/auth";

const route = useRoute();
const router = useRouter();
const state = ref("loading");
const message = ref("");
const { clearUser } = useAuth();
onMounted(async () => {
  try {
    await apiFetch("/api/v1/email_revert", { method: "POST", body: JSON.stringify({ token: route.query.token || "" }) });
    clearUser(); state.value = "done"; toast.success(t("security.email_reverted"));
    setTimeout(() => router.replace("/login"), 1500);
  } catch (error) { state.value = "error"; message.value = error.message; toast.error(error.message); }
});
</script>
<template><main class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12"><section class="w-full max-w-md rounded-3xl border border-gray-200 bg-white p-8 text-center shadow-theme-lg dark:border-gray-800 dark:bg-gray-900"><h1 class="text-2xl font-semibold dark:text-white">{{ t('security.email_revert_title') }}</h1><p class="mt-3 text-sm text-gray-500">{{ state === 'error' ? message : t('security.email_revert_hint') }}</p></section></main></template>
