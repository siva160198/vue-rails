<script setup>
import OtpInput from "./OtpInput.vue";
import { onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'
import AppModal from './AppModal.vue'
import AsyncButton from './AsyncButton.vue'
import FormField from './FormField.vue'
import TextInput from './TextInput.vue'
import TurnstileInput from './TurnstileInput.vue'
import { lockedAccount, clearSessionLock } from '../services/sessionLock'
import { apiFetch, resetApiSession } from '../services/api'
import { useAuth } from '../services/auth'
import { useFormErrors } from '../services/formErrors'
import { toast } from '../services/toast'
import { t } from '../services/i18n'

const router = useRouter()
const auth = useAuth()
const password = ref('')
const code = ref('')
const challenge = ref('')
const busy = ref(false)
const form = ref(null)
const captchaSiteKey = ref('')
const captchaToken = ref('')
const captcha = ref(null)
const errors = useFormErrors()
const resendIn = ref(0)
let cooldownTimer
function startCooldown(seconds) {
  clearInterval(cooldownTimer)
  resendIn.value = Number(seconds) || 60
  cooldownTimer = setInterval(() => {
    resendIn.value = Math.max(0, resendIn.value - 1)
    if (!resendIn.value) clearInterval(cooldownTimer)
  }, 1000)
}
onBeforeUnmount(() => clearInterval(cooldownTimer))

function restart() { if (!busy.value) { challenge.value = ''; code.value = ''; errors.clearErrors() } }

async function resend() {
  if (busy.value || resendIn.value > 0) return
  busy.value = true
  try {
    const response = await apiFetch('/api/v1/session/resend_otp', { method: 'POST', body: JSON.stringify({ challenge_token: challenge.value, unlock_token: lockedAccount.value.unlock_token }) })
    challenge.value = response.challenge_token; code.value = ''
    startCooldown(response.resend_in)
    toast.info(t('auth.otp_resent', { email: response.email_hint }))
  } catch (error) { toast.error(error.message) }
  finally { busy.value = false }
}

async function unlock() {
  if (busy.value) return
  const field = challenge.value ? 'code' : 'password'
  if (!await errors.validate({ [field]: () => (challenge.value ? code.value : password.value) ? '' : t('validation.required') }, form.value)) {
    toast.warning(t('validation.fix_fields')); return
  }
  busy.value = true
  try {
    const account = lockedAccount.value
    const response = await apiFetch(challenge.value ? '/api/v1/session/verify_otp' : '/api/v1/session/unlock', {
      method: 'POST', body: JSON.stringify({ unlock_token: account.unlock_token, password: password.value,
        challenge_token: challenge.value, code: code.value, captcha_token: captchaToken.value }),
    })
    password.value = ''
    if (response.otp_required) {
      challenge.value = response.challenge_token
      startCooldown(response.resend_in)
      toast.info(t('auth.otp_sent', { email: response.email_hint }))
      return
    }
    if (response.user.id !== account.id) throw new Error(t('auth.unlock_invalid'))
    resetApiSession()
    // Keep drafts mounted only when the renewed permissions still allow this page.
    const permission = router.currentRoute.value.meta.permission
    if (permission && !auth.can(permission, response.user)) {
      challenge.value = ''; code.value = ''
      errors.setError('password', t('error.403_message'))
      toast.error(t('error.403_message'))
      return
    }
    auth.setUser(response.user)
    clearSessionLock()
    toast.success(t('auth.session_unlocked'))
  } catch (error) {
    if (error.code === 'CAPTCHA_REQUIRED') captchaSiteKey.value = error.details.captcha_site_key
    await errors.applyApiError(error, form.value, field)
    toast.error(error.message)
  } finally {
    captchaToken.value = ''; captcha.value?.reset()
    busy.value = false
  }
}

function leave() {
  if (busy.value) return
  password.value = ''; code.value = ''
  resetApiSession()
  auth.clearUser()
  clearSessionLock()
  // A deliberate exit discards drafts and clears any still-valid session cookie.
  apiFetch('/api/v1/session', { method: 'DELETE' }).catch(() => {}).finally(() => {
    window.location.assign('/login')
  })
}
</script>

<template>
  <AppModal :open="Boolean(lockedAccount)" lock-screen close-disabled size="sm" :title="t('auth.session_locked')" :hint="t('auth.session_lock_hint')">
    <form ref="form" novalidate class="space-y-5" @submit.prevent="unlock">
      <p class="break-all text-sm text-gray-500">{{ lockedAccount?.email_address }}</p>
      <FormField v-if="!challenge" :label="t('auth.password')" :error="errors.errorFor('password')">
        <TextInput v-model="password" name="password" type="password" autocomplete="current-password" :disabled="busy" @input="errors.clearError('password')" />
      </FormField>
      <FormField v-else :label="t('auth.otp')" :help="t('auth.otp_or_recovery')" :error="errors.errorFor('code')">
        <OtpInput allow-recovery v-model="code" name="code" :disabled="busy" @input="errors.clearError('code')" />
      </FormField>
      <TurnstileInput v-if="captchaSiteKey && !challenge" ref="captcha" :site-key="captchaSiteKey" @verified="captchaToken = $event" @expired="captchaToken = ''" />
      <AsyncButton type="submit" :loading="busy" :disabled="Boolean(captchaSiteKey && !challenge && !captchaToken)" :loading-text="t('auth.verifying')" class="w-full rounded-xl bg-brand-500 px-4 py-3 font-semibold text-white">{{ t('auth.unlock') }}</AsyncButton>
      <div v-if="challenge" class="flex items-center justify-between text-sm">
        <button type="button" :disabled="busy" class="text-gray-500" @click="restart">{{ t('common.back') }}</button>
        <AsyncButton :loading="busy" :disabled="resendIn > 0" :loading-text="t('auth.resending')" class="text-brand-500" @click="resend">{{ resendIn > 0 ? t('auth.resend_countdown', { seconds: resendIn }) : t('auth.resend') }}</AsyncButton>
      </div>
      <button type="button" :disabled="busy" class="w-full text-sm font-semibold text-gray-500" @click="leave">{{ t('auth.discard_login') }}</button>
    </form>
  </AppModal>
</template>
