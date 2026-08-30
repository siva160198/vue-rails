<script setup>
import { onMounted, ref } from "vue";
import AsyncButton from "../AsyncButton.vue";
import FormField from "../FormField.vue";
import TableActionButton from "../TableActionButton.vue";
import StepUpPrompt from "../security/StepUpPrompt.vue";
import TextInput from "../TextInput.vue";
import { apiFetch } from "../../services/api";
import { useAuth } from "../../services/auth";
import { locale, t } from "../../services/i18n";
import { passkeysSupported, registerPasskey } from "../../services/passkeys";
import { confirmToast, toast } from "../../services/toast";
import { useFormErrors } from "../../services/formErrors";

const props = defineProps({ feature: { type: String, required: true } });
const emit = defineEmits(["saved"]);
const { user, setUser } = useAuth();
const passwordForm = ref({ current_password: "", password: "", password_confirmation: "" });
const emailForm = ref({ current_password: "", email_address: "", code: "" });
const recoveryForm = ref({ current_password: "", code: "" });
const passkeyForm = ref({ nickname: "", current_password: "" });
const totpForm = ref({ current_password: "", code: "" });
const emailChallenge = ref("");
const recoveryChallenge = ref("");
const recoveryCodes = ref([]);
const passkeys = ref([]);
const passkeysEnabled = ref(false);
const totpEnabled = ref(false);
const totpSetup = ref(null);
const passwordPending = ref(false);
const pendingPasskey = ref(null);
const loading = ref(false);
const action = ref("");
const removingId = ref(null);
const formElement = ref(null);
const formErrors = useFormErrors();

onMounted(async () => {
  if (!["passkeys", "totp"].includes(props.feature)) return;
  loading.value = true;
  try { const payload = await apiFetch("/api/v1/account_security?per_page=1"); passkeys.value = payload.passkeys || []; passkeysEnabled.value = Boolean(payload.passkeys_enabled); totpEnabled.value = Boolean(payload.totp_enabled); }
  catch (error) { toast.error(error.message); } finally { loading.value = false; }
});

async function changePassword() {
  if (action.value) return;
  const valid = await formErrors.validate({
    current_password: () => passwordForm.value.current_password ? "" : t("validation.required"),
    password: () => passwordForm.value.password.length < 12 ? t("validation.password_min") : passwordForm.value.password === passwordForm.value.current_password ? t("validation.password_same") : "",
    password_confirmation: () => !passwordForm.value.password_confirmation ? t("validation.required") : passwordForm.value.password !== passwordForm.value.password_confirmation ? t("validation.password_mismatch") : "",
  }, formElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  passwordPending.value = true;
}
async function finishPassword(stepUpToken) {
  action.value = "password";
  try { const { user: updated } = await apiFetch("/api/v1/account_security/password", { method: "PATCH", headers: { "X-Step-Up-Token": stepUpToken }, body: JSON.stringify({ password: passwordForm.value.password, password_confirmation: passwordForm.value.password_confirmation }) }); setUser(updated); toast.success(t("security.password_changed")); emit("saved"); }
  catch (error) { await formErrors.applyApiError(error, formElement.value, "password"); toast.error(error.message); } finally { action.value = ""; }
}
async function submitEmail() {
  if (action.value) return;
  const valid = await formErrors.validate(emailChallenge.value ? { code: () => /^\d{6}$/.test(emailForm.value.code) ? "" : t("validation.otp") } : { current_password: () => emailForm.value.current_password ? "" : t("validation.required"), email_address: () => !emailForm.value.email_address ? t("validation.required") : !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailForm.value.email_address) ? t("validation.email") : emailForm.value.email_address.toLowerCase() === user.value?.email_address?.toLowerCase() ? t("validation.email_same") : "" }, formElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  action.value = "email";
  try {
    if (!emailChallenge.value) { const payload = await apiFetch("/api/v1/account_security/request_email", { method: "POST", body: JSON.stringify(emailForm.value) }); emailChallenge.value = payload.challenge_token; toast.info(t("security.email_code_sent", { email: payload.email_hint })); }
    else { const { user: updated } = await apiFetch("/api/v1/account_security/verify_email", { method: "POST", body: JSON.stringify({ challenge_token: emailChallenge.value, code: emailForm.value.code }) }); setUser(updated); toast.success(t("security.email_changed")); emit("saved"); }
  } catch (error) { await formErrors.applyApiError(error, formElement.value, emailChallenge.value ? "code" : "current_password"); toast.error(error.message); } finally { action.value = ""; }
}
async function submitRecovery() {
  if (action.value) return;
  const valid = await formErrors.validate(recoveryChallenge.value ? { code: () => /^\d{6}$/.test(recoveryForm.value.code) ? "" : t("validation.otp") } : { current_password: () => recoveryForm.value.current_password ? "" : t("validation.required") }, formElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  action.value = "recovery";
  try {
    if (!recoveryChallenge.value) { const payload = await apiFetch("/api/v1/account_security/request_recovery_codes", { method: "POST", body: JSON.stringify(recoveryForm.value) }); recoveryChallenge.value = payload.challenge_token; toast.info(t("auth.otp_sent", { email: payload.email_hint })); }
    else { const payload = await apiFetch("/api/v1/account_security/verify_recovery_codes", { method: "POST", body: JSON.stringify({ challenge_token: recoveryChallenge.value, code: recoveryForm.value.code }) }); recoveryCodes.value = payload.recovery_codes; toast.success(t("security.recovery_generated")); }
  } catch (error) { await formErrors.applyApiError(error, formElement.value, recoveryChallenge.value ? "code" : "current_password"); toast.error(error.message); } finally { action.value = ""; }
}
async function addPasskey() {
  if (action.value) return;
  const valid = await formErrors.validate({ nickname: () => passkeyForm.value.nickname.trim() ? "" : t("validation.required"), current_password: () => passkeyForm.value.current_password ? "" : t("validation.required") }, formElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  action.value = "passkey";
  try { const { passkey } = await registerPasskey({ nickname: passkeyForm.value.nickname, currentPassword: passkeyForm.value.current_password }); passkeys.value.unshift(passkey); passkeyForm.value = { nickname: "", current_password: "" }; toast.success(t("security.passkey_added")); }
  catch (error) { const message = error.message === "PASSKEY_CANCELLED" ? t("security.passkeys_unsupported") : error.message; if (error.message !== "PASSKEY_CANCELLED") await formErrors.applyApiError(error, formElement.value, error.code === "CURRENT_PASSWORD_INVALID" ? "current_password" : ""); toast.error(message); } finally { action.value = ""; }
}
async function removePasskey(passkey) {
  if (!(await confirmToast(t("security.confirm_remove_passkey", { name: passkey.nickname }), { confirmLabel: t("common.delete") }))) return; removingId.value = passkey.id;
  pendingPasskey.value = passkey;
}
async function finishPasskeyRemoval(stepUpToken) {
  const passkey = pendingPasskey.value;
  try { await apiFetch(`/api/v1/passkeys/${passkey.id}`, { method: "DELETE", headers: { "X-Step-Up-Token": stepUpToken } }); passkeys.value = passkeys.value.filter(({ id }) => id !== passkey.id); pendingPasskey.value = null; toast.success(t("security.passkey_removed")); }
  catch (error) { toast.error(error.message); } finally { removingId.value = null; }
}
async function submitTotp() {
  if (action.value) return;
  const field = totpSetup.value ? "code" : "current_password";
  const valid = await formErrors.validate({ [field]: () => totpForm.value[field] ? "" : t("validation.required") }, formElement.value);
  if (!valid) return;
  action.value = "totp";
  try {
    if (!totpSetup.value) totpSetup.value = await apiFetch("/api/v1/account_security/request_totp", { method: "POST", body: JSON.stringify({ current_password: totpForm.value.current_password }) });
    else { await apiFetch("/api/v1/account_security/verify_totp", { method: "POST", body: JSON.stringify({ code: totpForm.value.code }) }); totpEnabled.value = true; totpSetup.value = null; toast.success(t("security.totp_enabled")); emit("saved"); }
  } catch (error) { await formErrors.applyApiError(error, formElement.value, field); toast.error(error.message); } finally { action.value = ""; }
}
async function disableTotp(stepUpToken) {
  action.value = "totp";
  try { await apiFetch("/api/v1/account_security/disable_totp", { method: "DELETE", headers: { "X-Step-Up-Token": stepUpToken } }); totpEnabled.value = false; toast.success(t("security.totp_disabled")); emit("saved"); }
  catch (error) { toast.error(error.message); } finally { action.value = ""; }
}
</script>

<template>
  <div v-if="loading" role="status" class="flex min-h-48 items-center justify-center text-sm text-gray-500">{{ t("common.loading_data") }}</div>
  <div v-else-if="feature === 'password'" class="space-y-4"><form ref="formElement" class="space-y-4" @submit.prevent="changePassword"><FormField :label="t('security.current_password')" :error="formErrors.errorFor('current_password')"><TextInput v-model="passwordForm.current_password" name="current_password" type="password" autocomplete="current-password" @input="formErrors.clearError('current_password')" /></FormField><FormField :label="t('auth.new_password')" :help="t('auth.password_min')" :error="formErrors.errorFor('password')"><TextInput v-model="passwordForm.password" name="password" type="password" autocomplete="new-password" @input="formErrors.clearError('password')" /></FormField><FormField :label="t('auth.confirm_password')" :error="formErrors.errorFor('password_confirmation')"><TextInput v-model="passwordForm.password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" @input="formErrors.clearError('password_confirmation')" /></FormField><AsyncButton type="submit" :loading="action === 'password'" :disabled="Boolean(action)" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t("common.continue") }}</AsyncButton></form><StepUpPrompt v-if="passwordPending" purpose="password_change" :initial-password="passwordForm.current_password" @verified="finishPassword" @cancel="passwordPending = false" /></div>
  <form v-else-if="feature === 'email'" ref="formElement" class="space-y-4" @submit.prevent="submitEmail"><template v-if="!emailChallenge"><FormField :label="t('security.current_password')" :error="formErrors.errorFor('current_password')"><TextInput v-model="emailForm.current_password" name="current_password" type="password" @input="formErrors.clearError('current_password')" /></FormField><FormField :label="t('security.new_email')" :error="formErrors.errorFor('email_address')"><TextInput v-model="emailForm.email_address" name="email_address" type="email" @input="formErrors.clearError('email_address')" /></FormField></template><FormField v-else :label="t('auth.otp')" :error="formErrors.errorFor('code')"><TextInput v-model="emailForm.code" name="code" inputmode="numeric" maxlength="6" @input="formErrors.clearError('code')" /></FormField><AsyncButton type="submit" :loading="action === 'email'" :disabled="Boolean(action)" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t(emailChallenge ? "security.verify_email" : "security.send_email_code") }}</AsyncButton></form>
  <form v-else-if="feature === 'recovery'" ref="formElement" class="space-y-4" @submit.prevent="submitRecovery"><FormField v-if="!recoveryChallenge" :label="t('security.current_password')" :error="formErrors.errorFor('current_password')"><TextInput v-model="recoveryForm.current_password" name="current_password" type="password" @input="formErrors.clearError('current_password')" /></FormField><FormField v-else :label="t('auth.otp')" :error="formErrors.errorFor('code')"><TextInput v-model="recoveryForm.code" name="code" inputmode="numeric" maxlength="6" @input="formErrors.clearError('code')" /></FormField><AsyncButton type="submit" :loading="action === 'recovery'" :disabled="Boolean(action)" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t(recoveryChallenge ? "security.regenerate" : "security.request_recovery") }}</AsyncButton><div v-if="recoveryCodes.length" class="grid grid-cols-2 gap-2 rounded-xl bg-brand-50 p-4 sm:grid-cols-4"><code v-for="code in recoveryCodes" :key="code" class="rounded bg-white px-2 py-2 text-center">{{ code }}</code></div></form>
  <div v-else-if="feature === 'totp'" class="space-y-4"><StepUpPrompt v-if="totpEnabled" purpose="totp_disable" @verified="disableTotp" @cancel="emit('saved')" /><form v-else ref="formElement" class="space-y-4" @submit.prevent="submitTotp"><FormField v-if="!totpSetup" :label="t('security.current_password')" :error="formErrors.errorFor('current_password')"><TextInput v-model="totpForm.current_password" name="current_password" type="password" /></FormField><template v-else><div class="rounded-xl bg-gray-50 p-4 text-sm dark:bg-gray-800"><p>{{ t('security.totp_setup_hint') }}</p><code class="mt-2 block break-all font-semibold">{{ totpSetup.secret }}</code></div><FormField :label="t('auth.otp')" :error="formErrors.errorFor('code')"><TextInput v-model="totpForm.code" name="code" inputmode="numeric" maxlength="6" /></FormField></template><AsyncButton type="submit" :loading="action === 'totp'" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t(totpSetup ? 'common.verify' : 'common.continue') }}</AsyncButton></form></div>
  <div v-else class="space-y-5"><p v-if="!passkeysEnabled" class="text-sm text-gray-500">{{ t("security.passkeys_disabled") }}</p><form v-else-if="passkeysSupported()" ref="formElement" class="space-y-4" @submit.prevent="addPasskey"><FormField :label="t('security.passkey_name')" :error="formErrors.errorFor('nickname')"><TextInput v-model="passkeyForm.nickname" name="nickname" maxlength="50" @input="formErrors.clearError('nickname')" /></FormField><FormField :label="t('security.current_password')" :error="formErrors.errorFor('current_password')"><TextInput v-model="passkeyForm.current_password" name="current_password" type="password" @input="formErrors.clearError('current_password')" /></FormField><AsyncButton type="submit" :loading="action === 'passkey'" :disabled="Boolean(action)" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t("security.add_passkey") }}</AsyncButton></form><p v-else class="text-sm text-error-600">{{ t("security.passkeys_unsupported") }}</p><ul class="divide-y divide-gray-100 dark:divide-gray-800"><li v-for="passkey in passkeys" :key="passkey.id" class="py-3"><div class="flex items-center justify-between"><div><p class="font-medium text-gray-800 dark:text-white">{{ passkey.nickname }}</p><p class="text-xs text-gray-500">{{ passkey.last_used_at ? new Date(passkey.last_used_at).toLocaleString(locale) : t("security.never_used") }}</p></div><TableActionButton action="delete" :label="t('common.delete')" :loading="removingId === passkey.id" @click="removePasskey(passkey)" /></div><StepUpPrompt v-if="pendingPasskey?.id === passkey.id" class="mt-3" purpose="passkey_delete" @verified="finishPasskeyRemoval" @cancel="pendingPasskey = null; removingId = null" /></li></ul></div>
</template>
