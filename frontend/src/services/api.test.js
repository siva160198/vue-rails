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
      }),
    }))
  })

  it('turns JSON API failures into errors with an HTTP status', async () => {
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
