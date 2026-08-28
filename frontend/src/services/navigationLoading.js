import { ref } from 'vue'

const MINIMUM_VISIBLE_MS = 250

export const navigationLoading = ref(false)

let startedAt = 0
let finishTimer

export function startNavigationLoading() {
  window.clearTimeout(finishTimer)
  startedAt = Date.now()
  navigationLoading.value = true
}

export function finishNavigationLoading() {
  const remaining = Math.max(0, MINIMUM_VISIBLE_MS - (Date.now() - startedAt))
  window.clearTimeout(finishTimer)
  finishTimer = window.setTimeout(() => {
    navigationLoading.value = false
  }, remaining)
}
