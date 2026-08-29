import { locale, t } from './i18n'

let csrfToken

async function getCsrfToken() {
  if (csrfToken) return csrfToken
  const response = await fetch('/api/v1/csrf', { credentials: 'include' })
  const data = await response.json()
  csrfToken = data.token
  return csrfToken
}

export async function apiFetch(path, options = {}) {
  const method = options.method || 'GET'
  const requestId = globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`
  const headers = { Accept: 'application/json', 'Accept-Language': locale.value, 'X-Request-ID': requestId, ...options.headers }

  if (!['GET', 'HEAD'].includes(method.toUpperCase())) {
    headers['X-CSRF-Token'] = await getCsrfToken()
    if (!(options.body instanceof FormData)) headers['Content-Type'] = 'application/json'
  }

  const response = await fetch(path, { ...options, method, headers, credentials: 'include' })
  const contentType = response.headers.get('content-type') || ''
  const data = response.status === 204
    ? null
    : contentType.includes('application/json')
      ? await response.json()
      : { error: { code: 'NON_JSON_RESPONSE', message: t('api.non_json_response', { status: response.status }), details: {} } }
  if (!response.ok) {
    const apiError = data?.error
    const message = typeof apiError === 'string' ? apiError : apiError?.message
    const error = new Error(message || `HTTP ${response.status}`)
    error.status = response.status
    error.code = typeof apiError === 'object' ? apiError.code : undefined
    error.details = typeof apiError === 'object' ? apiError.details || {} : data?.errors || {}
    error.requestId = response.headers.get('X-Request-ID') || requestId
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
