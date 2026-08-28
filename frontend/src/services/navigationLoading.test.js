import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { finishNavigationLoading, navigationLoading, startNavigationLoading } from './navigationLoading'

describe('navigation loading', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    navigationLoading.value = false
  })
  afterEach(() => vi.useRealTimers())

  it('blocks the interface during navigation and avoids a flashing spinner', () => {
    startNavigationLoading()
    expect(navigationLoading.value).toBe(true)

    finishNavigationLoading()
    vi.advanceTimersByTime(249)
    expect(navigationLoading.value).toBe(true)

    vi.advanceTimersByTime(1)
    expect(navigationLoading.value).toBe(false)
  })
})
