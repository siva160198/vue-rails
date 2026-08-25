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

test('member can register and verify email with OTP', async ({ page }) => {
  const email = `member-${Date.now()}@example.test`
  const beforeMail = await mailSnapshot()

  await page.goto('/register')
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password', { exact: true }).fill('member-secure-password')
  await page.getByLabel('Konfirmasi password').fill('member-secure-password')
  await page.getByRole('button', { name: 'Daftar', exact: true }).click()

  const mail = await waitForNewMail(beforeMail)
  const code = mail.match(/\b\d{6}\b/)[0]
  await page.getByLabel('Kode OTP').fill(code)
  await page.getByRole('button', { name: 'Verifikasi dan masuk' }).click()

  await expect(page).toHaveURL('/')
})

test('admin can login with password and email OTP', async ({ page }) => {
  const beforeMail = await mailSnapshot()

  await page.goto('/login')
  await page.getByLabel('Email').fill(adminEmail)
  await page.getByLabel('Password').fill(initialAdminPassword)
  await page.getByRole('button', { name: 'Login', exact: true }).click()

  const mail = await waitForNewMail(beforeMail)
  const code = mail.match(/\b\d{6}\b/)[0]
  await page.getByLabel('Kode OTP').fill(code)
  await page.getByRole('button', { name: 'Verifikasi', exact: true }).click()

  await expect(page).toHaveURL('/admin')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})

test('user can reset password from a signed email link', async ({ page }) => {
  const beforeMail = await mailSnapshot()

  await page.goto('/forgot-password')
  await page.getByLabel('Email').fill(adminEmail)
  await page.getByRole('button', { name: 'Kirim link reset' }).click()

  const mail = await waitForNewMail(beforeMail)
  const resetUrl = mail.match(/http:\/\/localhost:5173\/reset-password\?token=[^"<\s]+/)[0]
  await page.goto(resetUrl)
  await expect(page.getByLabel('Password baru')).toBeVisible()
  await page.getByLabel('Password baru').fill('new-e2e-admin-password')
  await page.getByLabel('Konfirmasi password').fill('new-e2e-admin-password')
  await page.getByRole('button', { name: 'Simpan password baru' }).click()

  await expect(page).toHaveURL(/\/login\?reset=success/)
  await expect(page.getByText('Password berhasil diperbarui')).toBeVisible()
})
