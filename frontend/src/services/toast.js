import { ref } from 'vue'
import { t } from './i18n'

export const toasts = ref([])

const durations = { success: 4000, info: 5000, warning: 6000, error: 8000 }
let nextId = 1

function schedule(toast) {
  if (toast.remaining <= 0) return
  toast.startedAt = Date.now()
  toast.timer = window.setTimeout(() => dismissToast(toast.id), toast.remaining)
}

export function showToast(message, type = 'info', options = {}) {
  const toast = {
    id: nextId++,
    type,
    title: options.title || t(`toast.${type}`),
    message,
    createdAt: new Date(),
    duration: options.duration ?? durations[type],
    remaining: options.duration ?? durations[type],
    timer: null,
    startedAt: null,
    paused: false,
    actions: options.actions || [],
    onDismiss: options.onDismiss,
  }
  toasts.value.push(toast)
  schedule(toast)
  return toast.id
}

export function dismissToast(id, notify = true) {
  const toast = toasts.value.find((item) => item.id === id)
  if (toast?.timer) window.clearTimeout(toast.timer)
  toasts.value = toasts.value.filter((item) => item.id !== id)
  if (notify) toast?.onDismiss?.()
}

export function pauseToast(id) {
  const toast = toasts.value.find((item) => item.id === id)
  if (!toast || toast.paused) return
  window.clearTimeout(toast.timer)
  toast.remaining = Math.max(0, toast.remaining - (Date.now() - toast.startedAt))
  toast.paused = true
}

export function resumeToast(id) {
  const toast = toasts.value.find((item) => item.id === id)
  if (!toast || !toast.paused) return
  toast.paused = false
  schedule(toast)
}

export const toast = {
  success: (message, options) => showToast(message, 'success', options),
  error: (message, options) => showToast(message, 'error', options),
  warning: (message, options) => showToast(message, 'warning', options),
  info: (message, options) => showToast(message, 'info', options),
}

export function confirmToast(message, options = {}) {
  return new Promise((resolve) => {
    let settled = false
    let id
    const finish = (value) => {
      if (settled) return
      settled = true
      dismissToast(id, false)
      resolve(value)
    }
    id = showToast(message, 'warning', {
      title: options.title || t('toast.confirm'),
      duration: 0,
      onDismiss: () => finish(false),
      actions: [
        { label: options.cancelLabel || t('toast.cancel'), style: 'secondary', handler: () => finish(false) },
        { label: options.confirmLabel || t('toast.continue'), style: 'danger', handler: () => finish(true) },
      ],
    })
  })
}
