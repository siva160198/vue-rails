import { expect, test } from '@playwright/test'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const testDirectory = path.dirname(fileURLToPath(import.meta.url))
const mailDirectory = path.resolve(testDirectory, '../../tmp/letter_opener')
const adminEmail = 'admin@example.test'
const initialAdminPassword = 'e2e-admin-password'

async function mailSnapshot() {
  try {
    return new Set(await fs.readdir(mailDirectory))
  } catch {
    return new Set()
  }
}

async function waitForNewMail(previousEntries) {
  return expect.poll(async () => {
    const entries = await fs.readdir(mailDirectory).catch(() => [])
    const newEntry = entries.find((entry) => !previousEntries.has(entry))
    if (!newEntry) return null

    const directory = path.join(mailDirectory, newEntry)
    const files = await fs.readdir(directory)
    const contents = await Promise.all(files.map((file) => fs.readFile(path.join(directory, file), 'utf8')))
    return contents.join('\n')
  }, { timeout: 10_000 }).not.toBeNull().then(async () => {
    const entries = await fs.readdir(mailDirectory)
    const newEntry = entries.find((entry) => !previousEntries.has(entry))
    const directory = path.join(mailDirectory, newEntry)
    const files = await fs.readdir(directory)
    return (await Promise.all(files.map((file) => fs.readFile(path.join(directory, file), 'utf8')))).join('\n')
  })
}

test.describe.configure({ mode: 'serial' })

test('forms explain invalid fields inline before sending requests', async ({ page }) => {
  await page.goto('/login')
  await page.getByRole('button', { name: 'Login', exact: true }).click()
  await expect(page.getByLabel('Email')).toHaveAttribute('aria-invalid', 'true')
  await expect(page.getByText('Field ini wajib diisi.').first()).toBeVisible()

  await page.goto('/register')
  await page.getByLabel('Email').fill('email-tidak-valid')
  await page.getByRole('button', { name: 'Daftar', exact: true }).click()
  await expect(page.getByLabel('Email')).toHaveAttribute('aria-invalid', 'true')
  await expect(page.getByText('Masukkan alamat email yang valid.')).toBeVisible()

  await page.goto('/forgot-password')
  await page.getByLabel('Email').fill('email-tidak-valid')
  await page.getByRole('button', { name: 'Kirim link reset' }).click()
  await expect(page.getByLabel('Email')).toHaveAttribute('aria-invalid', 'true')
  await expect(page.getByText('Masukkan alamat email yang valid.')).toBeVisible()
})

test('member can register and verify email with OTP', async ({ page }) => {
  const email = `member-${Date.now()}@example.test`
  const beforeMail = await mailSnapshot()

  await page.goto('/register')
  await page.getByLabel('Email').fill(email)
  await page.locator('input[autocomplete="new-password"]').first().fill('member-secure-password')
  await page.getByLabel('Konfirmasi kata sandi').fill('member-secure-password')
  await page.getByRole('button', { name: 'Daftar', exact: true }).click()

  const mail = await waitForNewMail(beforeMail)
  const code = mail.match(/\b\d{6}\b/)[0]
  await page.getByLabel('Kode OTP').fill(code)
  await page.getByRole('button', { name: 'Verifikasi dan masuk' }).click()

  await expect(page).toHaveURL('/')

  await page.goto('/admin')
  await expect(page).toHaveURL('/403')
  await expect(page.getByRole('heading', { name: 'Akses ditolak' })).toBeVisible()
})

test('admin can login with password and email OTP', async ({ page }) => {
  const beforeMail = await mailSnapshot()

  await page.goto('/login')
  await page.getByLabel('Email').fill(adminEmail)
  await page.getByLabel('Kata sandi').fill(initialAdminPassword)
  await page.getByRole('button', { name: 'Login', exact: true }).click()

  const mail = await waitForNewMail(beforeMail)
  const code = mail.match(/\b\d{6}\b/)[0]
  await page.getByLabel('Kode OTP').fill(code)
  await page.getByRole('button', { name: 'Verifikasi', exact: true }).click()

  await expect(page).toHaveURL('/admin')
  await expect(page.getByRole('heading', { name: 'Dasbor' })).toBeVisible()

  await page.goto('/admin/users')
  await expect(page.getByRole('heading', { name: 'Manajemen pengguna' })).toBeVisible()
  await expect(page.getByRole('table')).toBeVisible()

  await page.goto('/admin/roles')
  await expect(page.getByRole('heading', { name: 'Manajemen role' })).toBeVisible()
  await expect(page.getByRole('table')).toBeVisible()
  await page.getByRole('button', { name: /Edit role/ }).first().click()
  const editRoleDialog = page.getByRole('dialog', { name: 'Edit role' })
  await expect(editRoleDialog).toBeVisible()
  await editRoleDialog.getByRole('button', { name: /Lainnya/ }).click()
  await expect(page.getByRole('dialog', { name: 'Pilih permission' })).toBeVisible()
  await page.keyboard.press('Escape')
  await page.keyboard.press('Escape')

  await page.goto('/profile')
  await expect(page.getByRole('heading', { name: 'Perangkat aktif' })).toBeVisible()
  await page.locator('section').filter({ hasText: 'Perangkat aktif' }).getByRole('button', { name: 'Lihat' }).click()
  await expect(page.getByText('Saat ini')).toBeVisible()

  await page.goto('/admin/audit-logs')
  await expect(page.getByRole('heading', { name: 'Log audit' })).toBeVisible()

  await page.goto('/admin/jobs')
  await expect(page.getByRole('heading', { name: 'Antrean job' })).toBeVisible()

  await page.goto('/admin/api-docs')
  await expect(page.getByRole('heading', { name: 'Dokumentasi API' })).toBeVisible()
  await expect(page.locator('#swagger-ui')).toContainText('Vue Rails API')

  await page.setViewportSize({ width: 768, height: 1024 })
  await expect(page.getByRole('button', { name: 'Buka menu' })).toBeVisible()

  await page.setViewportSize({ width: 1440, height: 900 })
  await page.context().clearCookies()
  await page.getByRole('button', { name: 'Manajemen Pengguna' }).click()
  await page.getByRole('link', { name: 'Pengguna', exact: true }).click()
  await expect(page).toHaveURL(/\/login\?redirect=(%2F|\/)admin(%2F|\/)users/)
  await expect(page.getByText('Sesi Anda telah berakhir. Silakan login kembali.')).toBeVisible()
})

test('user can reset password from a signed email link', async ({ page }) => {
  const beforeMail = await mailSnapshot()

  await page.goto('/forgot-password')
  await page.getByLabel('Email').fill(adminEmail)
  await page.getByRole('button', { name: 'Kirim link reset' }).click()

  const mail = await waitForNewMail(beforeMail)
  const resetUrl = mail.match(/http:\/\/127\.0\.0\.1:5273\/reset-password\?token=[^"<\s]+/)[0]
  await page.goto(resetUrl)
  await expect(page.getByLabel('Kata sandi baru')).toBeVisible()
  await page.getByLabel('Kata sandi baru').fill('new-e2e-admin-password')
  await page.getByLabel('Konfirmasi kata sandi').fill('new-e2e-admin-password')
  await page.getByRole('button', { name: 'Simpan kata sandi baru' }).click()

  await expect(page).toHaveURL(/\/login\?reset=success/)
  await expect(page.getByText('Kata sandi berhasil diperbarui. Silakan login.')).toBeVisible()
})
