import { ref } from 'vue'

const messages = {
  id: { 'nav.home': 'Beranda', 'nav.admin': 'Admin', 'nav.language': 'Bahasa', 'common.loading_page': 'Memuat halaman…', 'auth.login_required': 'Silakan login terlebih dahulu untuk mengakses halaman admin.', 'auth.otp_sent': 'Kode OTP telah dikirim ke {email}.', 'auth.unverified': 'Akun belum terverifikasi. Kode verifikasi telah dikirim ke {email}.', 'auth.otp_resent': 'Kode OTP baru telah dikirim ke {email}.', 'auth.no_permission': 'Akun ini tidak memiliki izin untuk mengakses panel admin.', 'auth.password_updated': 'Kata sandi berhasil diperbarui. Silakan login.' },
  en: { 'nav.home': 'Home', 'nav.admin': 'Admin', 'nav.language': 'Language', 'common.loading_page': 'Loading page…', 'auth.login_required': 'Please sign in first to access the admin page.', 'auth.otp_sent': 'An OTP code was sent to {email}.', 'auth.unverified': 'Your account is not verified. A verification code was sent to {email}.', 'auth.otp_resent': 'A new OTP code was sent to {email}.', 'auth.no_permission': 'This account does not have permission to access the admin panel.', 'auth.password_updated': 'Password updated successfully. Please sign in.' },
}

const savedLocale = localStorage.getItem('locale')
export const locale = ref(savedLocale === 'en' ? 'en' : 'id')

export function setLocale(value) {
  locale.value = value === 'en' ? 'en' : 'id'
  localStorage.setItem('locale', locale.value)
  document.documentElement.lang = locale.value
}

export function t(key, params = {}) {
  let value = messages[locale.value]?.[key] || messages.id[key] || key
  Object.entries(params).forEach(([name, replacement]) => { value = value.replaceAll(`{${name}}`, replacement) })
  return value
}

setLocale(locale.value)
