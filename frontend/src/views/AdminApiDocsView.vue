<script setup>
import { nextTick, onMounted, ref } from "vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import { t } from "../services/i18n";
import "swagger-ui-dist/swagger-ui.css";

const loading = ref(true);
onMounted(async () => {
  const { default: SwaggerUI } = await import("swagger-ui-dist/swagger-ui-es-bundle.js");
  await nextTick();
  SwaggerUI({ dom_id: "#swagger-ui", url: "/api/v1/admin/api_docs", deepLinking: true, persistAuthorization: false, requestInterceptor: (request) => { request.credentials = "include"; return request; } });
  loading.value = false;
});
</script>

<template><AdminLayout><div class="mx-auto max-w-[1536px]"><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t("api_docs.title") }}</h1><p class="mt-1 text-sm text-gray-500">{{ t("api_docs.subtitle") }}</p><div class="relative mt-6 min-h-96 rounded-xl border border-gray-200 bg-white p-4 dark:border-gray-800"><div v-if="loading" class="absolute inset-0 z-10 flex items-center justify-center bg-white/80"><span class="h-8 w-8 animate-spin rounded-full border-2 border-brand-500 border-t-transparent"></span></div><div id="swagger-ui"></div></div></div></AdminLayout></template>
