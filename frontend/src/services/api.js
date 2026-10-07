import { locale, t } from './i18n'
import { notifyAuthenticationRequired } from './sessionExpiration'
import { lockedAccount } from './sessionLock'

let csrfToken
let csrfPromise
const DEFAULT_TIMEOUT_MS = 15_000
let requestEpoch = 0
const activeRequests = new Set()

export function resetApiSession() {
  requestEpoch += 1
  csrfToken = undefined
  csrfPromise = undefined
  for (const controller of activeRequests) controller.abort()
}

function cancelledRequest() {
  return Object.assign(new Error(t('api.request_cancelled')), { code: 'REQUEST_ABORTED', details: {} })
}

async function getCsrfToken() {
  if (csrfToken) return csrfToken
  if (!csrfPromise) {
    const epoch = requestEpoch
    csrfPromise = apiRequest('/api/v1/csrf', { credentials: 'include' }).then(async (response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      if (epoch !== requestEpoch) throw cancelledRequest()
      csrfToken = data.token
      return csrfToken
    }).finally(() => { if (epoch === requestEpoch) csrfPromise = undefined })
  }
  return csrfPromise
}

function requestSignal(externalSignal, timeoutMs) {
  const controller = new AbortController()
  activeRequests.add(controller)
  let timedOut = false
  const abort = () => controller.abort(externalSignal?.reason)
  if (externalSignal?.aborted) abort()
  else externalSignal?.addEventListener('abort', abort, { once: true })
  const timer = setTimeout(() => { timedOut = true; controller.abort() }, timeoutMs)
  return { signal: controller.signal, timedOut: () => timedOut, cleanup: () => { activeRequests.delete(controller); clearTimeout(timer); externalSignal?.removeEventListener('abort', abort) } }
}

async function apiRequest(path, options = {}) {
  const { timeoutMs: requestedTimeout, signal: externalSignal, ...fetchOptions } = options
  const configuredTimeout = Number(requestedTimeout || import.meta.env.VITE_API_TIMEOUT_MS || DEFAULT_TIMEOUT_MS)
  const timeoutMs = Number.isFinite(configuredTimeout) ? Math.max(1_000, Math.min(configuredTimeout, 120_000)) : DEFAULT_TIMEOUT_MS
  const bounded = requestSignal(externalSignal, timeoutMs)
  const epoch = requestEpoch
  try {
    const response = await fetch(path, { ...fetchOptions, signal: bounded.signal })
    if (epoch !== requestEpoch) throw cancelledRequest()
    return response
  } catch (error) {
    if (error.name !== 'AbortError') throw error
    const requestError = new Error(t(bounded.timedOut() ? 'api.request_timeout' : 'api.request_cancelled'))
    requestError.code = bounded.timedOut() ? 'REQUEST_TIMEOUT' : 'REQUEST_ABORTED'
    requestError.details = {}
    throw requestError
  } finally {
    bounded.cleanup()
  }
}

export async function apiFetch(path, options = {}) {
  if (lockedAccount.value && !['/api/v1/csrf', '/api/v1/session/unlock', '/api/v1/session/verify_otp', '/api/v1/session/resend_otp'].includes(path)) throw cancelledRequest()
  const epoch = requestEpoch
  const method = options.method || 'GET'
  const requestId = globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`
  const headers = { Accept: 'application/json', 'Accept-Language': locale.value, 'X-Request-ID': requestId, ...options.headers }

  if (!['GET', 'HEAD'].includes(method.toUpperCase())) {
    headers['X-CSRF-Token'] = await getCsrfToken()
    if (!(options.body instanceof FormData)) headers['Content-Type'] = 'application/json'
  }

  if (epoch !== requestEpoch) throw cancelledRequest()

  const response = await apiRequest(path, { ...options, method, headers, credentials: 'include' })
  const contentType = response.headers.get('content-type') || ''
  const data = response.status === 204
    ? null
    : contentType.includes('application/json')
      ? await response.json()
      : { error: { code: 'NON_JSON_RESPONSE', message: t('api.non_json_response', { status: response.status }), details: {} } }
  if (epoch !== requestEpoch) throw cancelledRequest()
  if (!response.ok) {
    const apiError = data?.error
    const message = typeof apiError === 'string' ? apiError : apiError?.message
    const error = new Error(message || `HTTP ${response.status}`)
    error.status = response.status
    error.code = typeof apiError === 'object' ? apiError.code : undefined
    error.details = typeof apiError === 'object' ? apiError.details || {} : data?.errors || {}
    error.requestId = response.headers.get('X-Request-ID') || requestId
    if (error.status === 401 && error.code === 'AUTHENTICATION_REQUIRED') {
      resetApiSession()
      notifyAuthenticationRequired(error)
    }
    throw error
  }
  return data
}

export async function currentUser() {
  try {
    return (await apiFetch('/api/v1/session')).user
  } catch (error) {
    if (error.status === 401) return null
    throw error
  }
}
