<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { apiFetch } from "../services/api";
import { toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import { t } from "../services/i18n";
import { useAuth } from "../services/auth";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";

const route = useRoute();
const router = useRouter();
const { setUser, logout, can } = useAuth();
const email = ref("");
const password = ref("");
const code = ref("");
const challengeToken = ref("");
const emailHint = ref("");
const loading = ref(false);
const resendLoading = ref(false);
const resendIn = ref(0);
let cooldownTimer;
const emailValid = computed(() =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value),
);
const formValid = computed(() =>
  challengeToken.value
    ? /^(\d{6}|[a-f0-9]{10})$/.test(code.value)
    : emailValid.value && password.value.length > 0,
);

function startResendCooldown(seconds) {
  window.clearInterval(cooldownTimer);
  resendIn.value = Number(seconds) || 0;
  if (resendIn.value <= 0) return;
  cooldownTimer = window.setInterval(() => {
    resendIn.value -= 1;
    if (resendIn.value <= 0) window.clearInterval(cooldownTimer);
  }, 1000);
}

async function login() {
  if (loading.value || !formValid.value) return;
  loading.value = true;
  try {
    const response = await apiFetch("/api/v1/session", {
      method: "POST",
      body: JSON.stringify({
        email_address: email.value,
        password: password.value,
      }),
    });
    if (!response.otp_required) {
      await completeLogin(response.user);
      return;
    }
    challengeToken.value = response.challenge_token;
    emailHint.value = response.email_hint;
    startResendCooldown(response.resend_in);
    if (response.account_unverified) {
      toast.warning(t("auth.unverified", { email: response.email_hint }));
    } else {
      toast.info(t("auth.otp_sent", { email: response.email_hint }));
    }
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    loading.value = false;
  }
}

async function completeLogin(user) {
  if (user.permissions.length === 0) {
    await logout();
    toast.error(t("auth.no_permission"));
    return;
  }
  setUser(user);
  const defaultPath = can("dashboard.view")
    ? "/admin"
    : can("users.view")
      ? "/admin/users"
      : can("roles.view")
        ? "/admin/roles"
        : "/admin/audit-logs";
  await router.push(route.query.redirect || defaultPath);
}

async function verifyOtp() {
  if (loading.value || !formValid.value) return;
  loading.value = true;
  try {
    const { user } = await apiFetch("/api/v1/session/verify_otp", {
      method: "POST",
      body: JSON.stringify({
        challenge_token: challengeToken.value,
        code: code.value,
      }),
    });
    await completeLogin(user);
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    loading.value = false;
  }
}

async function resendOtp() {
  if (resendLoading.value || resendIn.value > 0) return;
  resendLoading.value = true;
  try {
    const response = await apiFetch("/api/v1/session/resend_otp", {
      method: "POST",
      body: JSON.stringify({ challenge_token: challengeToken.value }),
    });
    challengeToken.value = response.challenge_token;
    code.value = "";
    startResendCooldown(response.resend_in);
    toast.info(t("auth.otp_resent", { email: response.email_hint }));
  } catch (requestError) {
    toast.error(requestError.message);
  } finally {
    resendLoading.value = false;
  }
}

function restartLogin() {
  window.clearInterval(cooldownTimer);
  resendIn.value = 0;
  challengeToken.value = "";
  code.value = "";
}

onMounted(() => {
  if (route.query.reset === "success")
    toast.success(t("auth.password_updated"));
});
onBeforeUnmount(() => window.clearInterval(cooldownTimer));
</script>

<template>
  <main
    class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12"
  >
    <form
      class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60"
      @submit.prevent="challengeToken ? verifyOtp() : login()"
    >
      <p
        class="text-sm font-semibold uppercase tracking-[0.2em] text-brand-600"
      >
        {{ t("auth.admin_access") }}
      </p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">
        {{ t(challengeToken ? "auth.verify_title" : "auth.login_title") }}
      </h1>
      <p class="mt-2 text-sm text-slate-500">
        {{
          challengeToken
            ? t("auth.otp_hint", { email: emailHint })
            : t("auth.login_hint")
        }}
      </p>
      <div v-if="!challengeToken" class="mt-8 space-y-5">
        <FormField :label="t('auth.email')">
          <TextInput
            v-model="email"
            :disabled="loading"
            type="email"
            autocomplete="email"
            required
          />
        </FormField>
        <FormField :label="t('auth.password')">
          <TextInput
            v-model="password"
            :disabled="loading"
            type="password"
            autocomplete="current-password"
            required
          />
          <template #after><RouterLink
            to="/forgot-password"
            class="mt-2 block text-right text-xs font-semibold text-brand-600 hover:text-brand-500"
            >{{ t("auth.forgot") }}</RouterLink
          ></template>
        </FormField>
      </div>
      <div v-else class="mt-8">
        <FormField :label="t('auth.otp')" :help="t('auth.otp_or_recovery')">
          <TextInput
            v-model="code"
            :disabled="loading"
            type="text"
            inputmode="text"
            autocomplete="one-time-code"
            pattern="([0-9]{6}|[a-f0-9]{10})"
            maxlength="10"
            required
            autofocus
            class="text-center text-2xl font-bold tracking-[0.45em]"
          />
        </FormField>
      </div>
      <AsyncButton
        type="submit"
        :loading="loading"
        :disabled="resendLoading || !formValid"
        :loading-text="t(challengeToken ? 'auth.verifying' : 'auth.logging_in')"
        class="mt-6 w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white hover:bg-brand-600"
        >{{ t(challengeToken ? "auth.verify" : "auth.login") }}</AsyncButton
      >
      <div
        v-if="challengeToken"
        class="mt-5 flex items-center justify-between text-sm"
      >
        <button
          type="button"
          :disabled="loading"
          class="font-medium text-slate-500 hover:text-slate-900 disabled:opacity-50"
          @click="restartLogin"
        >
          {{ t("common.back") }}
        </button>
        <AsyncButton
          :loading="resendLoading"
          :disabled="loading || resendIn > 0"
          :loading-text="t('auth.resending')"
          class="font-semibold text-brand-600 hover:text-brand-500"
          @click="resendOtp"
          >{{
            resendIn > 0
              ? t("auth.resend_countdown", { seconds: resendIn })
              : t("auth.resend")
          }}</AsyncButton
        >
      </div>
      <p v-else class="mt-5 text-center text-sm text-slate-500">
        {{ t("auth.no_account") }}
        <RouterLink
          to="/register"
          class="font-semibold text-brand-600 hover:text-brand-500"
          >{{ t("auth.register_member") }}</RouterLink
        >
      </p>
    </form>
  </main>
</template>
