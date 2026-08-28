import { locale } from './i18n'

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
  const headers = { Accept: 'application/json', 'Accept-Language': locale.value, ...options.headers }

  if (!['GET', 'HEAD'].includes(method.toUpperCase())) {
    headers['X-CSRF-Token'] = await getCsrfToken()
    headers['Content-Type'] = 'application/json'
  }

  const response = await fetch(path, { ...options, method, headers, credentials: 'include' })
  const contentType = response.headers.get('content-type') || ''
  const data = response.status === 204
    ? null
    : contentType.includes('application/json')
      ? await response.json()
      : { error: `Server mengembalikan respons non-JSON (HTTP ${response.status}).` }
  if (!response.ok) {
    const error = new Error(data?.error || `HTTP ${response.status}`)
    error.status = response.status
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
