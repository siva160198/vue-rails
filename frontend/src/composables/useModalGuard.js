import { inject, onBeforeUnmount, watchEffect } from 'vue'

export const modalGuardKey = Symbol('modalGuard')

// Register reactive child form state without lifting passwords/OTP into the parent.
export function useModalGuard(state) {
  const guard = inject(modalGuardKey, null)
  const token = Symbol('form')
  watchEffect(() => guard?.states.set(token, state()))
  onBeforeUnmount(() => guard?.states.delete(token))
  return { requestClose: guard ? () => guard.requestClose() : null }
}
