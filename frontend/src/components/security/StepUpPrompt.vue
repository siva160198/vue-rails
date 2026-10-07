<script setup>
import OtpInput from "../OtpInput.vue";
import { ref } from "vue";
import { useModalGuard } from '../../composables/useModalGuard';
import AsyncButton from "../AsyncButton.vue";
import FormField from "../FormField.vue";
import TextInput from "../TextInput.vue";
import { apiFetch } from "../../services/api";
import { t } from "../../services/i18n";
import { toast } from "../../services/toast";
import { useFormErrors } from "../../services/formErrors";

const props = defineProps({ purpose: { type: String, required: true }, initialPassword: { type: String, default: "" } });
const emit = defineEmits(["verified", "cancel"]);
const form = ref({ current_password: props.initialPassword, code: "" });
const challenge = ref("");
const loading = ref(false);
const element = ref(null);
const errors = useFormErrors();
const { requestClose } = useModalGuard(() => ({ dirty: Boolean(form.value.current_password || form.value.code || challenge.value), busy: loading.value }));
function cancel() { if (requestClose) requestClose(); else emit('cancel'); }

async function submit() {
  const field = challenge.value ? "code" : "current_password";
  const valid = await errors.validate({ [field]: () => form.value[field] ? "" : t("validation.required") }, element.value);
  if (!valid || loading.value) return;
  loading.value = true;
  try {
    if (!challenge.value) {
      const payload = await apiFetch("/api/v1/step_up", { method: "POST", body: JSON.stringify({ purpose: props.purpose, current_password: form.value.current_password }) });
      challenge.value = payload.challenge_token;
      toast.info(t("auth.otp_sent", { email: payload.email_hint }));
    } else {
      const payload = await apiFetch("/api/v1/step_up/verify", { method: "POST", body: JSON.stringify({ purpose: props.purpose, challenge_token: challenge.value, code: form.value.code }) });
      emit("verified", payload.step_up_token);
    }
  } catch (error) {
    await errors.applyApiError(error, element.value, field);
    toast.error(error.message);
  } finally { loading.value = false; }
}
</script>

<template>
  <form ref="element" novalidate class="space-y-4 rounded-xl border border-gray-200 bg-gray-50 p-4 dark:border-gray-800 dark:bg-gray-950/40" @submit.prevent="submit">
    <p class="text-sm text-gray-600 dark:text-gray-300">{{ t("security.step_up_hint") }}</p>
    <FormField v-if="!challenge" :label="t('security.current_password')" :error="errors.errorFor('current_password')"><TextInput v-model="form.current_password" name="current_password" type="password" autocomplete="current-password" :disabled="loading" @input="errors.clearError('current_password')" /></FormField>
    <FormField v-else :label="t('auth.otp')" :help="t('security.totp_or_email_hint')" :error="errors.errorFor('code')"><OtpInput v-model="form.code" name="code" :disabled="loading" @input="errors.clearError('code')" /></FormField>
    <div class="flex justify-end gap-2"><AsyncButton type="button" class="rounded-lg border border-gray-200 px-3 py-2 text-sm" :disabled="loading" @click="cancel">{{ t("common.cancel") }}</AsyncButton><AsyncButton v-if="!challenge" type="submit" :loading="loading" class="rounded-lg bg-brand-500 px-3 py-2 text-sm font-semibold text-white">{{ t(challenge ? "common.verify" : "common.continue") }}</AsyncButton></div>
  </form>
</template>
