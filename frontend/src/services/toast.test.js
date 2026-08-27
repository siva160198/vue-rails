import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { confirmToast, dismissToast, pauseToast, resumeToast, toast, toasts } from './toast'

describe('toast', () => {
  beforeEach(() => { vi.useFakeTimers(); toasts.value = [] })
  afterEach(() => vi.useRealTimers())

  it('creates and automatically dismisses a notification', () => {
    toast.success('Tersimpan')
    expect(toasts.value[0]).toMatchObject({ type: 'success', message: 'Tersimpan' })
    vi.advanceTimersByTime(4000)
    expect(toasts.value).toHaveLength(0)
  })

  it('can pause, resume, and close a notification', () => {
    const id = toast.error('Gagal')
    vi.advanceTimersByTime(1000)
    pauseToast(id)
    vi.advanceTimersByTime(8000)
    expect(toasts.value).toHaveLength(1)
    resumeToast(id)
    dismissToast(id)
    expect(toasts.value).toHaveLength(0)
  })

  it('resolves a toast confirmation action', async () => {
    const confirmation = confirmToast('Hapus role?')
    toasts.value[0].actions[1].handler()
    await expect(confirmation).resolves.toBe(true)
    expect(toasts.value).toHaveLength(0)
  })
})
