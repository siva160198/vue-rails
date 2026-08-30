<script setup>
import { computed, defineAsyncComponent, onMounted, ref } from "vue";
import { Camera, CheckCircle2, Edit3, KeyRound, LoaderCircle, Mail, MonitorSmartphone, Phone, ShieldCheck, Trash2, UserRound, View, XCircle } from "@lucide/vue";
import AdminLayout from "../components/admin/AdminLayout.vue";
import AppModal from "../components/AppModal.vue";
import AsyncButton from "../components/AsyncButton.vue";
import FormField from "../components/FormField.vue";
import TextInput from "../components/TextInput.vue";
import { apiFetch } from "../services/api";
import { useAuth } from "../services/auth";
import { locale, t } from "../services/i18n";
import { toast } from "../services/toast";
import { useFormErrors } from "../services/formErrors";

const ProfileSecurityEditor = defineAsyncComponent(() => import("../components/profile/ProfileSecurityEditor.vue"));
const AdminSessionsView = defineAsyncComponent(() => import("./AdminSessionsView.vue"));
const LoginHistoryPanel = defineAsyncComponent(() => import("../components/profile/LoginHistoryPanel.vue"));
const AvatarCropEditor = defineAsyncComponent(() => import("../components/profile/AvatarCropEditor.vue"));
const { user, setUser, can } = useAuth();
const profile = ref(null);
const loading = ref(true);
const avatarInput = ref(null);
const avatarAction = ref("");
const avatarSourceFile = ref(null);
const modal = ref("");
const personalForm = ref({ first_name: "", last_name: "", phone: "" });
const savingPersonal = ref(false);
const personalFormElement = ref(null);
const personalErrors = useFormErrors();
const initial = computed(() => profile.value?.first_name?.charAt(0).toUpperCase() || profile.value?.email_address?.charAt(0).toUpperCase() || "U");
const fullName = computed(() => [profile.value?.first_name, profile.value?.last_name].filter(Boolean).join(" ") || profile.value?.email_address?.split("@")[0]);
const personalDirty = computed(() => ["first_name", "last_name", "phone"].some((key) => (personalForm.value[key] || "") !== (profile.value?.[key] || "")));
const modalTitle = computed(() => avatarSourceFile.value ? t("profile.crop_title") : ({ personal: t("profile.edit_personal"), password: t("security.change_password"), email: t("security.change_email"), recovery: t("security.recovery_title"), passkeys: t("security.passkeys"), totp: t("security.totp_title"), devices: t("sessions.title"), history: t("security.login_history") }[modal.value] || ""));

async function loadProfile() {
  loading.value = true;
  try { const payload = await apiFetch("/api/v1/profile"); profile.value = payload.profile; }
  catch (error) { toast.error(error.message); } finally { loading.value = false; }
}
function openPersonal() {
  avatarSourceFile.value = null;
  personalErrors.clearErrors();
  personalForm.value = { first_name: profile.value.first_name || "", last_name: profile.value.last_name || "", phone: profile.value.phone || "" };
  modal.value = "personal";
}
async function savePersonal() {
  if (!personalDirty.value || savingPersonal.value) return;
  const valid = await personalErrors.validate({
    first_name: () => personalForm.value.first_name.length > 80 ? t("validation.too_long") : "",
    last_name: () => personalForm.value.last_name.length > 80 ? t("validation.too_long") : "",
    phone: () => personalForm.value.phone && !/^[+0-9() .-]+$/.test(personalForm.value.phone) ? t("validation.phone") : "",
  }, personalFormElement.value);
  if (!valid) { toast.warning(t("validation.fix_fields")); return; }
  savingPersonal.value = true;
  try {
    const payload = await apiFetch("/api/v1/profile", { method: "PATCH", body: JSON.stringify(personalForm.value) });
    profile.value = payload.profile;
    setUser({ ...user.value, first_name: profile.value.first_name, last_name: profile.value.last_name });
    modal.value = ""; toast.success(t("profile.personal_updated"));
  } catch (error) { await personalErrors.applyApiError(error, personalFormElement.value); toast.error(error.message); } finally { savingPersonal.value = false; }
}
function selectAvatar(event) {
  const file = event.target.files?.[0]; event.target.value = "";
  if (!file || avatarAction.value) return;
  personalErrors.clearError("avatar");
  if (file.size > 10 * 1024 * 1024) { personalErrors.setError("avatar", t("profile.avatar_source_too_large")); toast.error(t("profile.avatar_source_too_large")); return; }
  if (!file.type.startsWith("image/") || file.type === "image/svg+xml") { personalErrors.setError("avatar", t("profile.avatar_type_error")); toast.error(t("profile.avatar_type_error")); return; }
  avatarSourceFile.value = file;
}
async function uploadAvatar(file) {
  if (!file || avatarAction.value) return; personalErrors.clearError("avatar"); avatarAction.value = "upload";
  try { const body = new FormData(); body.append("avatar", file); const payload = await apiFetch("/api/v1/profile", { method: "PATCH", body }); profile.value = { ...profile.value, avatar_url: payload.avatar_url }; setUser({ ...user.value, avatar_url: payload.avatar_url }); toast.success(t("profile.avatar_updated")); }
  catch (error) { personalErrors.setError("avatar", error.message); toast.error(error.message); } finally { avatarAction.value = ""; avatarSourceFile.value = null; }
}
function closePersonalModal() { if (avatarSourceFile.value) avatarSourceFile.value = null; else modal.value = ""; }
function cropError(message) { personalErrors.setError("avatar", message); toast.error(message); avatarSourceFile.value = null; }
async function removeAvatar() {
  if (!profile.value?.avatar_url || avatarAction.value) return; avatarAction.value = "remove";
  try { await apiFetch("/api/v1/profile", { method: "DELETE" }); profile.value = { ...profile.value, avatar_url: null }; setUser({ ...user.value, avatar_url: null }); personalErrors.clearError("avatar"); toast.success(t("profile.avatar_removed")); }
  catch (error) { personalErrors.setError("avatar", error.message); toast.error(error.message); } finally { avatarAction.value = ""; }
}
function securitySaved() { modal.value = ""; loadProfile(); }
onMounted(loadProfile);
</script>

<template>
  <AdminLayout><div class="mx-auto max-w-[1200px] space-y-6">
    <header><h1 class="text-2xl font-semibold text-gray-900 dark:text-white">{{ t("profile.title") }}</h1><p class="mt-1 text-sm text-gray-500">{{ t("profile.subtitle") }}</p></header>
    <div v-if="loading" role="status" class="flex min-h-80 items-center justify-center rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900"><LoaderCircle :size="26" class="animate-spin text-brand-500" /></div>
    <template v-else-if="profile">
      <section class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900 sm:p-6">
        <div class="flex flex-col items-center gap-5 sm:flex-row sm:items-center">
          <div class="flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-full border-4 border-white bg-brand-100 text-3xl font-semibold text-brand-600 shadow-theme-md dark:border-gray-900 dark:bg-brand-500/15 dark:text-brand-400"><img v-if="profile.avatar_url" :src="profile.avatar_url" :alt="t('profile.avatar_alt')" class="h-full w-full object-cover" /><span v-else>{{ initial }}</span></div>
          <div class="min-w-0 flex-1 text-center sm:text-left"><h2 class="truncate text-xl font-semibold text-gray-900 dark:text-white">{{ fullName }}</h2><p class="mt-1 truncate text-sm text-gray-500">{{ profile.email_address }}</p><div class="mt-3 flex flex-wrap justify-center gap-2 sm:justify-start"><span class="rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold capitalize text-brand-600 dark:bg-brand-500/10 dark:text-brand-400">{{ profile.role }}</span><span class="inline-flex items-center gap-1 text-xs text-gray-500"><CheckCircle2 v-if="profile.email_verified_at" :size="15" class="text-brand-500" /><XCircle v-else :size="15" class="text-error-600" />{{ t(profile.email_verified_at ? "profile.verified" : "profile.unverified") }}</span></div></div>
        </div>
      </section>

      <section class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900 sm:p-6">
        <div class="flex items-center justify-between gap-4"><div><h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t("profile.personal_information") }}</h2><p class="mt-1 text-sm text-gray-500">{{ t("profile.personal_hint") }}</p></div><AsyncButton v-if="can('profile.update')" class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200" @click="openPersonal"><Edit3 :size="16" />{{ t("common.edit") }}</AsyncButton></div>
        <dl class="mt-6 grid gap-5 border-t border-gray-100 pt-5 dark:border-gray-800 sm:grid-cols-2 lg:grid-cols-3"><div><dt class="text-xs text-gray-400">{{ t("profile.first_name") }}</dt><dd class="mt-1 font-medium text-gray-800 dark:text-gray-200">{{ profile.first_name || '—' }}</dd></div><div><dt class="text-xs text-gray-400">{{ t("profile.last_name") }}</dt><dd class="mt-1 font-medium text-gray-800 dark:text-gray-200">{{ profile.last_name || '—' }}</dd></div><div><dt class="text-xs text-gray-400">{{ t("profile.phone") }}</dt><dd class="mt-1 font-medium text-gray-800 dark:text-gray-200">{{ profile.phone || '—' }}</dd></div><div><dt class="text-xs text-gray-400">{{ t("auth.email") }}</dt><dd class="mt-1 break-all font-medium text-gray-800 dark:text-gray-200">{{ profile.email_address }}</dd></div><div><dt class="text-xs text-gray-400">{{ t("users.role") }}</dt><dd class="mt-1 capitalize font-medium text-gray-800 dark:text-gray-200">{{ profile.role }}</dd></div><div><dt class="text-xs text-gray-400">{{ t("profile.member_since") }}</dt><dd class="mt-1 font-medium text-gray-800 dark:text-gray-200">{{ new Date(profile.created_at).toLocaleDateString(locale) }}</dd></div></dl>
      </section>

      <section v-if="can('account_security.view')" class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900 sm:p-6"><div><h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t("security.title") }}</h2><p class="mt-1 text-sm text-gray-500">{{ t("security.subtitle") }}</p></div><div class="mt-5 divide-y divide-gray-100 border-t border-gray-100 dark:divide-gray-800 dark:border-gray-800"><div v-for="item in [{ key: 'password', icon: KeyRound, title: t('security.change_password'), hint: t('profile.password_hint') }, { key: 'email', icon: Mail, title: t('security.change_email'), hint: t('profile.email_hint') }, { key: 'totp', icon: ShieldCheck, title: t('security.totp_title'), hint: t('security.totp_hint') }, { key: 'recovery', icon: ShieldCheck, title: t('security.recovery_title'), hint: t('security.recovery_hint') }, { key: 'passkeys', icon: UserRound, title: t('security.passkeys'), hint: t('security.passkey_hint') }]" :key="item.key" class="flex items-center gap-4 py-4"><span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400"><component :is="item.icon" :size="19" /></span><div class="min-w-0 flex-1"><h3 class="text-sm font-semibold text-gray-800 dark:text-white">{{ item.title }}</h3><p class="mt-1 truncate text-xs text-gray-500">{{ item.hint }}</p></div><AsyncButton v-if="can('account_security.update')" class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="modal = item.key"><Edit3 :size="16" /><span class="hidden sm:inline">{{ t("common.edit") }}</span></AsyncButton></div></div></section>

      <div class="grid gap-6 lg:grid-cols-2"><section v-if="can('sessions.view')" class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900 sm:p-6"><div class="flex items-start justify-between gap-4"><span class="flex h-11 w-11 items-center justify-center rounded-full bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400"><MonitorSmartphone :size="21" /></span><AsyncButton class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="modal = 'devices'"><View :size="16" />{{ t("common.view") }}</AsyncButton></div><h2 class="mt-5 text-lg font-semibold text-gray-900 dark:text-white">{{ t("sessions.title") }}</h2><p class="mt-1 text-sm text-gray-500">{{ t("sessions.subtitle") }}</p></section><section v-if="can('account_security.view')" class="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900 sm:p-6"><div class="flex items-start justify-between gap-4"><span class="flex h-11 w-11 items-center justify-center rounded-full bg-brand-50 text-brand-600 dark:bg-brand-500/10 dark:text-brand-400"><ShieldCheck :size="21" /></span><AsyncButton class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="modal = 'history'"><View :size="16" />{{ t("common.view") }}</AsyncButton></div><h2 class="mt-5 text-lg font-semibold text-gray-900 dark:text-white">{{ t("security.login_history") }}</h2><p class="mt-1 text-sm text-gray-500">{{ t("profile.history_hint") }}</p></section></div>
    </template>

    <AppModal :open="modal === 'personal'" :title="modalTitle" :hint="avatarSourceFile ? t('profile.crop_hint') : t('profile.personal_hint')" :close-disabled="savingPersonal || Boolean(avatarAction)" @close="closePersonalModal"><Suspense v-if="avatarSourceFile"><AvatarCropEditor :file="avatarSourceFile" :loading="avatarAction === 'upload'" @cancel="avatarSourceFile = null" @confirm="uploadAvatar" @error="cropError" /><template #fallback><div role="status" class="flex min-h-64 items-center justify-center"><LoaderCircle :size="26" class="animate-spin text-brand-500" /></div></template></Suspense><template v-else><div class="mb-6 flex flex-col gap-4 rounded-xl border border-gray-200 p-4 dark:border-gray-800 sm:flex-row sm:items-center"><div class="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-full bg-brand-100 text-2xl font-semibold text-brand-600 dark:bg-brand-500/15 dark:text-brand-400"><img v-if="profile.avatar_url" :src="profile.avatar_url" :alt="t('profile.avatar_alt')" class="h-full w-full object-cover" /><span v-else>{{ initial }}</span></div><div class="min-w-0 flex-1"><h3 class="text-sm font-semibold text-gray-900 dark:text-white">{{ t("profile.avatar_title") }}</h3><p class="mt-1 text-xs text-gray-500">{{ t("profile.avatar_conversion_hint") }}</p><div class="mt-3 flex flex-wrap gap-2"><AsyncButton :disabled="Boolean(avatarAction)" class="rounded-lg bg-brand-500 px-3 py-2 text-sm font-semibold text-white" @click="avatarInput?.click()"><Camera :size="16" />{{ t("profile.change_photo") }}</AsyncButton><AsyncButton v-if="profile.avatar_url" :loading="avatarAction === 'remove'" :disabled="Boolean(avatarAction)" class="rounded-lg border border-error-200 px-3 py-2 text-sm font-semibold text-error-700 hover:bg-error-50" @click="removeAvatar"><Trash2 :size="16" />{{ t("profile.remove") }}</AsyncButton></div><p v-if="personalErrors.errorFor('avatar').length" role="alert" class="mt-2 text-xs text-error-700">{{ personalErrors.errorFor('avatar').join(', ') }}</p><input ref="avatarInput" name="avatar" type="file" class="sr-only" accept="image/jpeg,image/png,image/webp,image/avif,image/heic,image/heif,image/gif" @change="selectAvatar" /></div></div><form id="personal-profile-form" ref="personalFormElement" class="grid gap-4 sm:grid-cols-2" @submit.prevent="savePersonal"><FormField :label="t('profile.first_name')" :error="personalErrors.errorFor('first_name')"><TextInput v-model="personalForm.first_name" name="first_name" maxlength="80" autocomplete="given-name" @input="personalErrors.clearError('first_name')" /></FormField><FormField :label="t('profile.last_name')" :error="personalErrors.errorFor('last_name')"><TextInput v-model="personalForm.last_name" name="last_name" maxlength="80" autocomplete="family-name" @input="personalErrors.clearError('last_name')" /></FormField><FormField class="sm:col-span-2" :label="t('profile.phone')" :error="personalErrors.errorFor('phone')"><TextInput v-model="personalForm.phone" name="phone" maxlength="30" type="tel" autocomplete="tel" @input="personalErrors.clearError('phone')" /></FormField></form></template><template v-if="!avatarSourceFile" #footer><AsyncButton type="button" class="rounded-lg border border-gray-200 px-4 py-2.5 text-sm font-medium text-gray-700" :disabled="savingPersonal || Boolean(avatarAction)" @click="modal = ''">{{ t("common.cancel") }}</AsyncButton><AsyncButton type="submit" form="personal-profile-form" :loading="savingPersonal" :disabled="!personalDirty || savingPersonal || Boolean(avatarAction)" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white">{{ t("common.save") }}</AsyncButton></template></AppModal>
    <AppModal :open="['password','email','totp','recovery','passkeys'].includes(modal)" :title="modalTitle" size="md" @close="modal = ''"><Suspense><ProfileSecurityEditor v-if="['password','email','totp','recovery','passkeys'].includes(modal)" :feature="modal" @saved="securitySaved" /><template #fallback><div role="status" class="flex min-h-48 items-center justify-center"><LoaderCircle :size="26" class="animate-spin text-brand-500" /></div></template></Suspense></AppModal>
    <AppModal :open="modal === 'devices'" :title="modalTitle" size="xl" @close="modal = ''"><Suspense><AdminSessionsView v-if="modal === 'devices'" embedded /><template #fallback><div role="status" class="flex min-h-64 items-center justify-center"><LoaderCircle :size="26" class="animate-spin text-brand-500" /></div></template></Suspense></AppModal>
    <AppModal :open="modal === 'history'" :title="modalTitle" size="xl" @close="modal = ''"><Suspense><LoginHistoryPanel v-if="modal === 'history'" /><template #fallback><div role="status" class="flex min-h-64 items-center justify-center"><LoaderCircle :size="26" class="animate-spin text-brand-500" /></div></template></Suspense></AppModal>
  </div></AdminLayout>
</template>
