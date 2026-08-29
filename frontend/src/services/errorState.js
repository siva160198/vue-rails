import { shallowRef } from 'vue'
import { captureAppError } from './observability'

export const appError = shallowRef(null)

export function reportAppError(error) {
  appError.value = error instanceof Error ? error : new Error(String(error))
  captureAppError(appError.value)
}

export function clearAppError() {
  appError.value = null
}
