<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { apiFetch } from "../services/api";
import { toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import { t } from "../services/i18n";
import { useAuth } from "../services/auth";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";
import { authenticateWithPasskey, passkeysSupported } from "../services/passkeys";
import TurnstileInput from "../components/TurnstileInput.vue";
import { useFormErrors } from "../services/formErrors";

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
const passkeyLoading = ref(false);
const captchaSiteKey = ref("");
const captchaToken = ref("");
const turnstileInput = ref(null);
const loginForm = ref(null);
const formErrors = useFormErrors();
const resendIn = ref(0);
let cooldownTimer;
const emailValid = computed(() =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value),
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
  if (loading.value) return;
  const valid = await formErrors.validate({
    email_address: () => !email.value ? t("validation.required") : !emailValid.value ? t("validation.email") : "",
    password: () => password.value ? "" : t("validation.required"),
  }, loginForm.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  loading.value = true;
  try {
    const response = await apiFetch("/api/v1/session", {
      method: "POST",
      body: JSON.stringify({
        email_address: email.value,
        password: password.value,
        captcha_token: captchaToken.value,
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
    if (requestError.code === "CAPTCHA_REQUIRED") {
      captchaSiteKey.value = requestError.details?.captcha_site_key || "";
      captchaToken.value = "";
      await nextTick();
    }
    await formErrors.applyApiError(requestError, loginForm.value, "password"); toast.error(requestError.message);
  } finally {
    if (captchaToken.value) {
      captchaToken.value = "";
      turnstileInput.value?.reset();
    }
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

async function passkeyLogin() {
  if (passkeyLoading.value) return;
  const valid = await formErrors.validate({ email_address: () => !email.value ? t("validation.required") : !emailValid.value ? t("validation.email") : "" }, loginForm.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  passkeyLoading.value = true;
  try {
    const { user } = await authenticateWithPasskey(email.value);
    await completeLogin(user);
  } catch (requestError) {
    if (requestError.message !== "PASSKEY_CANCELLED") await formErrors.applyApiError(requestError, loginForm.value, "email_address");
    toast.error(requestError.message === "PASSKEY_CANCELLED" ? t("security.passkeys_unsupported") : requestError.message);
  } finally {
    passkeyLoading.value = false;
  }
}

async function verifyOtp() {
  if (loading.value) return;
  const valid = await formErrors.validate({ code: () => /^\d{6}$|^[a-f0-9]{10}$/.test(code.value) ? "" : t("validation.otp_or_recovery") }, loginForm.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
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
    await formErrors.applyApiError(requestError, loginForm.value, "code"); toast.error(requestError.message);
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
      ref="loginForm"
      novalidate
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
        <FormField :label="t('auth.email')" :error="formErrors.errorFor('email_address')">
          <TextInput
            v-model="email"
            name="email_address"
            :disabled="loading"
            type="email"
            autocomplete="email"
            required
            @input="formErrors.clearError('email_address')"
          />
        </FormField>
        <TurnstileInput v-if="captchaSiteKey" ref="turnstileInput" :site-key="captchaSiteKey" @verified="captchaToken = $event" @expired="captchaToken = ''" @error="captchaToken = ''" />
        <FormField :label="t('auth.password')" :error="formErrors.errorFor('password')">
          <TextInput
            v-model="password"
            name="password"
            :disabled="loading"
            type="password"
            autocomplete="current-password"
            required
            @input="formErrors.clearError('password')"
          />
          <template #after><RouterLink
            to="/forgot-password"
            class="mt-2 block text-right text-xs font-semibold text-brand-600 hover:text-brand-500"
            >{{ t("auth.forgot") }}</RouterLink
          ></template>
        </FormField>
      </div>
      <div v-else class="mt-8">
        <FormField :label="t('auth.otp')" :help="t('auth.otp_or_recovery')" :error="formErrors.errorFor('code')">
          <TextInput
            v-model="code"
            name="code"
            :disabled="loading"
            type="text"
            inputmode="text"
            autocomplete="one-time-code"
            pattern="([0-9]{6}|[a-f0-9]{10})"
            maxlength="10"
            required
            autofocus
            class="text-center text-2xl font-bold tracking-[0.45em]"
            @input="formErrors.clearError('code')"
          />
        </FormField>
      </div>
      <AsyncButton
        type="submit"
        :loading="loading"
        :disabled="resendLoading || Boolean(captchaSiteKey && !captchaToken)"
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
      <AsyncButton
        v-if="!challengeToken && passkeysSupported()"
        type="button"
        :loading="passkeyLoading"
        :disabled="loading || !emailValid"
        :loading-text="t('security.using_passkey')"
        class="mt-3 w-full rounded-xl border border-gray-300 px-4 py-3 font-semibold text-gray-700 hover:bg-gray-50"
        @click="passkeyLogin"
      >{{ t("security.use_passkey") }}</AsyncButton>
      <p v-if="!challengeToken" class="mt-5 text-center text-sm text-slate-500">
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
