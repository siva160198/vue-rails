import { mount, flushPromises } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ref } from 'vue'
import axe from 'axe-core'
import SessionLockModal from './SessionLockModal.vue'
import { lockedAccount, clearSessionLock } from '../services/sessionLock'

const mocks = vi.hoisted(() => ({ apiFetch: vi.fn(), resetApiSession: vi.fn(), setUser: vi.fn(), clearUser: vi.fn(), toast: { warning: vi.fn(), info: vi.fn(), error: vi.fn(), success: vi.fn() } }))
const route = ref({ meta: { permission: 'profile.view' } })
vi.mock('vue-router', () => ({ useRouter: () => ({ currentRoute: route }) }))
vi.mock('../services/api', () => ({ apiFetch: mocks.apiFetch, resetApiSession: mocks.resetApiSession }))
vi.mock('../services/auth', () => ({ useAuth: () => ({ setUser: mocks.setUser, clearUser: mocks.clearUser, can: (permission, user) => user.permissions.includes(permission) }) }))
vi.mock('../services/toast', () => ({ toast: mocks.toast }))

let wrapper
beforeEach(() => {
  vi.clearAllMocks()
  lockedAccount.value = { id: 1, email_address: 'one@example.com', unlock_token: 'context' }
})
afterEach(() => { wrapper?.unmount(); clearSessionLock(); document.body.innerHTML = '' })

function open() { wrapper = mount(SessionLockModal, { attachTo: document.body }); return wrapper }
async function submit(value, name = 'password') {
  const input = document.querySelector(`[name="${name}"]`)
  input.value = value
  input.dispatchEvent(new Event('input', { bubbles: true }))
  document.querySelector('form').dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
  await flushPromises()
}

describe('SessionLockModal', () => {
  it('cannot dismiss through Escape and explains missing password inline', async () => {
    open(); await flushPromises()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    await submit('')
    expect(lockedAccount.value).not.toBeNull()
    expect(document.querySelector('[name="password"]').getAttribute('aria-invalid')).toBe('true')
    expect(mocks.apiFetch).not.toHaveBeenCalled()
    const result = await axe.run(document.querySelector('[role="dialog"]'), { rules: { 'color-contrast': { enabled: false } } })
    expect(result.violations).toEqual([])
  })

  it('verifies MFA and refreshes identity without navigating or replaying writes', async () => {
    mocks.apiFetch.mockResolvedValueOnce({ otp_required: true, challenge_token: 'otp', email_hint: 'o***@example.com' })
      .mockResolvedValueOnce({ user: { id: 1, permissions: ['profile.view'], unlock_token: 'fresh' } })
    open()
    await submit('password')
    expect(document.querySelector('[name="code"]')).not.toBeNull()
    await submit('123456', 'code')
    expect(mocks.apiFetch.mock.calls[1][0]).toBe('/api/v1/session/verify_otp')
    expect(mocks.setUser).toHaveBeenCalledOnce()
    expect(lockedAccount.value).toBeNull()
  })

  it('remains locked if page permission was revoked and displays server validation', async () => {
    mocks.apiFetch.mockRejectedValueOnce(Object.assign(new Error('Wrong password'), { details: { password: ['Wrong password'] } }))
      .mockResolvedValueOnce({ user: { id: 1, permissions: [] } })
    open()
    await submit('wrong')
    expect(document.body.textContent).toContain('Wrong password')
    await submit('correct')
    expect(lockedAccount.value).not.toBeNull()
    expect(mocks.toast.error).toHaveBeenCalled()
  })
})
