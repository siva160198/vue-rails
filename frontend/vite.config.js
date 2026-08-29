import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  base: process.env.NODE_ENV === 'production' ? '/frontend/' : '/',
  test: {
    environment: 'jsdom',
    exclude: ['e2e/**', 'node_modules/**', 'dist/**'],
    globals: true,
    setupFiles: './src/test/setup.js',
    coverage: {
      provider: 'v8',
      reportsDirectory: '../tmp/frontend-coverage',
      reporter: ['text', 'html', 'json-summary'],
      include: ['src/components/**/*.vue', 'src/services/**/*.js'],
      exclude: ['src/**/*.test.js', 'src/test/**'],
      thresholds: { lines: 70, functions: 70, branches: 65, statements: 70 },
    },
  },
  server: {
    proxy: {
      '/api': {
        target: process.env.VITE_RAILS_URL || 'http://localhost:3000',
        changeOrigin: true,
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyRequest) => {
            proxyRequest.setHeader('Origin', process.env.VITE_RAILS_URL || 'http://localhost:3000')
          })
        },
      },
    },
  },
})
