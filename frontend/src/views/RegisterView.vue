<script setup>
import { computed, onBeforeUnmount, ref } from "vue";
import { useRouter } from "vue-router";
import { apiFetch } from "../services/api";
import { toast } from "../services/toast";
import AsyncButton from "../components/AsyncButton.vue";
import { t } from "../services/i18n";
import { useAuth } from "../services/auth";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";
import { useFormErrors } from "../services/formErrors";

const router = useRouter();
const { setUser } = useAuth();
const email = ref("");
const password = ref("");
const passwordConfirmation = ref("");
const code = ref("");
const challengeToken = ref("");
const emailHint = ref("");
const loading = ref(false);
const registrationForm = ref(null);
const { errorFor, clearError, clearErrors, validate, applyApiError } = useFormErrors();
const resendLoading = ref(false);
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

async function register() {
  if (loading.value) return;
  const valid = await validateRegistration();
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }

  loading.value = true;
  clearErrors();
  try {
    const response = await apiFetch("/api/v1/registration", {
      method: "POST",
      body: JSON.stringify({
        email_address: email.value,
        password: password.value,
        password_confirmation: passwordConfirmation.value,
      }),
    });
    challengeToken.value = response.challenge_token;
    emailHint.value = response.email_hint;
    startResendCooldown(response.resend_in);
    if (response.account_unverified) {
      toast.warning(t("auth.unverified", { email: response.email_hint }));
    } else {
      toast.info(t("auth.otp_sent", { email: response.email_hint }));
    }
  } catch (requestError) {
    await applyApiError(requestError, registrationForm.value); toast.error(requestError.message);
  } finally {
    loading.value = false;
  }
}

async function verifyOtp() {
  if (loading.value) return;
  const valid = await validate({ code: () => /^\d{6}$/.test(code.value) ? "" : t("validation.otp") }, registrationForm.value);
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
    setUser(user);
    await router.push("/");
  } catch (requestError) {
    await applyApiError(requestError, registrationForm.value); toast.error(requestError.message);
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
onBeforeUnmount(() => window.clearInterval(cooldownTimer));

function validateRegistration() {
  return validate({
    email_address: () => !email.value ? t("validation.required") : !emailValid.value ? t("validation.email") : "",
    password: () => password.value.length < 12 ? t("validation.password_min") : "",
    password_confirmation: () => !passwordConfirmation.value ? t("validation.required") : password.value !== passwordConfirmation.value ? t("validation.password_mismatch") : "",
  }, registrationForm.value);
}
</script>

<template>
  <main
    class="flex min-h-[calc(100vh-65px)] items-center justify-center px-6 py-12"
  >
    <form
      ref="registrationForm"
      novalidate
      class="w-full max-w-md rounded-3xl border border-slate-200 bg-white p-8 shadow-xl shadow-slate-200/60"
      @submit.prevent="challengeToken ? verifyOtp() : register()"
    >
      <p
        class="text-sm font-semibold uppercase tracking-[0.2em] text-brand-600"
      >
        {{ t("auth.registration") }}
      </p>
      <h1 class="mt-3 text-3xl font-bold tracking-tight">
        {{ t(challengeToken ? "auth.verify_email" : "auth.register_title") }}
      </h1>
      <p class="mt-2 text-sm text-slate-500">
        {{
          challengeToken
            ? t("auth.otp_hint", { email: emailHint })
            : t("auth.register_hint")
        }}
      </p>

      <div v-if="!challengeToken" class="mt-8 space-y-5">
        <FormField :label="t('auth.email')" :error="errorFor('email_address')">
          <TextInput
            v-model="email"
            name="email_address"
            :disabled="loading"
            type="email"
            autocomplete="email"
            required
            @input="clearError('email_address')"
          />
        </FormField>
        <FormField :label="t('auth.password')" :help="t('auth.password_min')" :error="errorFor('password')">
          <TextInput
            v-model="password"
            name="password"
            :disabled="loading"
            type="password"
            autocomplete="new-password"
            minlength="12"
            required
            @input="clearError('password')"
          />
        </FormField>
        <FormField :label="t('auth.confirm_password')" :error="errorFor('password_confirmation')">
          <TextInput
            v-model="passwordConfirmation"
            name="password_confirmation"
            :disabled="loading"
            type="password"
            autocomplete="new-password"
            minlength="12"
            required
            @input="clearError('password_confirmation')"
          />
        </FormField>
      </div>

      <div v-else class="mt-8">
        <FormField :label="t('auth.otp')" :error="errorFor('code')">
          <TextInput
            v-model="code"
            name="code"
            :disabled="loading"
            type="text"
            inputmode="numeric"
            autocomplete="one-time-code"
            pattern="[0-9]{6}"
            maxlength="6"
            required
            autofocus
            class="text-center text-2xl font-bold tracking-[0.45em]"
            @input="clearError('code')"
          />
        </FormField>
      </div>

      <AsyncButton
        type="submit"
        :loading="loading"
        :disabled="resendLoading"
        :loading-text="
          t(challengeToken ? 'auth.verifying' : 'auth.registering')
        "
        class="mt-6 w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white hover:bg-brand-600"
        >{{
          t(challengeToken ? "auth.verify_and_login" : "auth.register")
        }}</AsyncButton
      >

      <div class="mt-5 flex items-center justify-between text-sm">
        <RouterLink
          to="/login"
          class="font-medium text-gray-500 hover:text-gray-900"
          >{{ t("auth.have_account") }}</RouterLink
        >
        <AsyncButton
          v-if="challengeToken"
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
    </form>
  </main>
</template>
