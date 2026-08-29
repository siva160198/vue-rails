import { defineConfig, devices } from '@playwright/test'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const adminEmail = 'admin@example.test'
const adminPassword = 'e2e-admin-password'
const frontendDirectory = path.dirname(fileURLToPath(import.meta.url))
const railsDirectory = path.resolve(frontendDirectory, '..')

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: 'http://127.0.0.1:5273',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: [
    {
      name: 'rails',
      command: 'bin/rails db:prepare db:seed && bin/rails runner test/e2e/setup.rb && bin/rails server -p 3100',
      cwd: railsDirectory,
      url: 'http://127.0.0.1:3100/up',
      reuseExistingServer: false,
      timeout: 120_000,
      env: {
        ...process.env,
        RAILS_ENV: 'test',
        E2E: 'true',
        FRONTEND_URL: 'http://127.0.0.1:5273',
        ADMIN_EMAIL: adminEmail,
        ADMIN_PASSWORD: adminPassword,
        E2E_ADMIN_EMAIL: adminEmail,
        E2E_ADMIN_PASSWORD: adminPassword,
      },
    },
    {
      name: 'vite',
      command: 'npm run dev -- --host 127.0.0.1 --port 5273',
      cwd: frontendDirectory,
      url: 'http://127.0.0.1:5273',
      reuseExistingServer: false,
      timeout: 120_000,
      env: { ...process.env, VITE_RAILS_URL: 'http://127.0.0.1:3100' },
    },
  ],
})
