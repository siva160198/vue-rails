import { afterEach, describe, expect, it } from 'vitest'
import { locale, setLocale, t } from './i18n'

describe('native i18n', () => {
  afterEach(() => setLocale('id'))

  it('switches language, persists it, and interpolates values', () => {
    setLocale('en')
    expect(locale.value).toBe('en')
    expect(localStorage.getItem('locale')).toBe('en')
    expect(document.documentElement.lang).toBe('en')
    expect(t('auth.otp_sent', { email: 'a***@mail.com' })).toContain('a***@mail.com')
  })
})
