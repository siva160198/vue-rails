import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('apiFetch', () => {
  beforeEach(() => {
    vi.resetModules()
    vi.restoreAllMocks()
  })

  it('adds CSRF and JSON headers to state-changing requests', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ token: 'csrf-token' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }))
    vi.stubGlobal('fetch', fetchMock)
    const { apiFetch } = await import('./api')

    await apiFetch('/api/v1/example', { method: 'POST', body: '{}' })

    expect(fetchMock).toHaveBeenNthCalledWith(2, '/api/v1/example', expect.objectContaining({
      credentials: 'include',
      headers: expect.objectContaining({
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': 'csrf-token',
        'X-Request-ID': expect.any(String),
      }),
    }))
  })

  it('deduplicates concurrent CSRF requests', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ token: 'shared-token' }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
      .mockImplementation(() => Promise.resolve(new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'Content-Type': 'application/json' } })))
    vi.stubGlobal('fetch', fetchMock)
    const { apiFetch } = await import('./api')

    await Promise.all([
      apiFetch('/api/v1/one', { method: 'POST', body: '{}' }),
      apiFetch('/api/v1/two', { method: 'POST', body: '{}' }),
    ])

    expect(fetchMock).toHaveBeenCalledTimes(3)
    expect(fetchMock.mock.calls.filter(([path]) => path === '/api/v1/csrf')).toHaveLength(1)
  })

  it('returns a stable error when a request times out', async () => {
    vi.useFakeTimers()
    vi.stubGlobal('fetch', vi.fn((_path, { signal }) => new Promise((_resolve, reject) => {
      signal.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')), { once: true })
    })))
    const { apiFetch } = await import('./api')
    const request = apiFetch('/api/v1/slow', { timeoutMs: 1000 })
    const rejection = expect(request).rejects.toMatchObject({ code: 'REQUEST_TIMEOUT' })
    await vi.advanceTimersByTimeAsync(1000)
    await rejection
    vi.useRealTimers()
  })

  it('lets the browser set the multipart boundary for FormData', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ token: 'csrf-token' }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ avatar_url: '/avatar' }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
    vi.stubGlobal('fetch', fetchMock)
    const { apiFetch } = await import('./api')
    const body = new FormData()
    body.append('avatar', new Blob(['image']), 'avatar.png')

    await apiFetch('/api/v1/profile', { method: 'PATCH', body })

    expect(fetchMock.mock.calls[1][1].headers['Content-Type']).toBeUndefined()
  })

  it('turns JSON API failures into errors with an HTTP status', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({
      error: { code: 'FORBIDDEN', message: 'Ditolak', details: { permission: ['required'] } },
    }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })))
    const { apiFetch } = await import('./api')

    await expect(apiFetch('/api/v1/protected')).rejects.toMatchObject({
      message: 'Ditolak',
      status: 403,
      code: 'FORBIDDEN',
      details: { permission: ['required'] },
      requestId: expect.any(String),
    })
  })

  it('notifies the global session handler only for authentication-required 401 responses', async () => {
    const handler = vi.fn()
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'Expired', details: {} } }), { status: 401, headers: { 'Content-Type': 'application/json' } }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ error: { code: 'INVALID_CREDENTIALS', message: 'Wrong', details: {} } }), { status: 401, headers: { 'Content-Type': 'application/json' } })))
    const { registerAuthenticationRequiredHandler } = await import('./sessionExpiration')
    const { apiFetch } = await import('./api')
    registerAuthenticationRequiredHandler(handler)

    await expect(apiFetch('/api/v1/protected')).rejects.toMatchObject({ code: 'AUTHENTICATION_REQUIRED' })
    await expect(apiFetch('/api/v1/fake-login')).rejects.toMatchObject({ code: 'INVALID_CREDENTIALS' })

    expect(handler).toHaveBeenCalledOnce()
  })

  it('keeps compatibility with legacy string errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: 'Ditolak' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })))
    const { apiFetch } = await import('./api')

    await expect(apiFetch('/api/v1/protected')).rejects.toMatchObject({ message: 'Ditolak', status: 403 })
  })

  it('handles non-JSON server responses without parsing failures', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('<html>Error</html>', {
      status: 500,
      headers: { 'Content-Type': 'text/html' },
    })))
    const { apiFetch } = await import('./api')

    await expect(apiFetch('/api/v1/broken')).rejects.toThrow('Server mengembalikan respons non-JSON')
  })
})
