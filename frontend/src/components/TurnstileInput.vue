<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { locale, t } from "../services/i18n";

const props = defineProps({ siteKey: { type: String, required: true } });
const emit = defineEmits(["verified", "expired", "error"]);
const container = ref(null);
let widgetId;
let scriptPromise;

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile);
  scriptPromise ||= new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-vue-rails-turnstile]');
    if (existing) {
      existing.addEventListener("load", () => resolve(window.turnstile), { once: true });
      existing.addEventListener("error", reject, { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    script.defer = true;
    script.dataset.vueRailsTurnstile = "true";
    script.onload = () => resolve(window.turnstile);
    script.onerror = reject;
    document.head.appendChild(script);
  });
  return scriptPromise;
}

async function renderWidget() {
  if (!container.value || !props.siteKey) return;
  const turnstile = await loadTurnstile();
  if (!turnstile) throw new Error("Turnstile unavailable");
  if (widgetId !== undefined) turnstile.remove(widgetId);
  await nextTick();
  widgetId = turnstile.render(container.value, {
    sitekey: props.siteKey,
    theme: "auto",
    size: "flexible",
    language: locale.value,
    action: "login",
    callback: (token) => emit("verified", token),
    "expired-callback": () => emit("expired"),
    "error-callback": () => emit("error"),
  });
}

function reset() {
  if (widgetId !== undefined) window.turnstile?.reset(widgetId);
}

defineExpose({ reset });
onMounted(() => renderWidget().catch(() => emit("error")));
watch(() => props.siteKey, () => renderWidget().catch(() => emit("error")));
onBeforeUnmount(() => { if (widgetId !== undefined) window.turnstile?.remove(widgetId); });
</script>

<template>
  <div class="rounded-xl border border-gray-200 bg-gray-50 p-3 dark:border-gray-800 dark:bg-gray-900">
    <p class="mb-3 text-sm text-gray-500">{{ t("auth.captcha_hint") }}</p>
    <div ref="container" class="min-h-[65px]" />
  </div>
</template>
