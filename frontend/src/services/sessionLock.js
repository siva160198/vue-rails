import { ref } from 'vue'

// Memory only: never persist account context, drafts, passwords, or OTP in storage.
export const lockedAccount = ref(null)
export function lockSession(user) {
  if (!lockedAccount.value) lockedAccount.value = { ...user }
}
export function clearSessionLock() { lockedAccount.value = null }
