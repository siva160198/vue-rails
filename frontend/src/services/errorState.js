import { shallowRef } from 'vue'

export const appError = shallowRef(null)

export function reportAppError(error) {
  appError.value = error instanceof Error ? error : new Error(String(error))
}

export function clearAppError() {
  appError.value = null
}
