<script setup>
import { locale, setLocale, t } from '../services/i18n'

function chooseLanguage(value, event) {
  setLocale(value)
  event.currentTarget.closest('details')?.removeAttribute('open')
}
</script>

<template>
  <details class="group relative">
    <summary :aria-label="t('nav.language')" class="flex h-10 w-10 cursor-pointer list-none items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-100 dark:border-gray-800 dark:hover:bg-gray-800">
      <svg v-if="locale === 'id'" viewBox="0 0 24 16" class="h-4 w-6 overflow-hidden rounded-sm ring-1 ring-gray-900/10" aria-hidden="true"><path fill="#e70011" d="M0 0h24v8H0z"/><path fill="#fff" d="M0 8h24v8H0z"/></svg>
      <svg v-else viewBox="0 0 24 16" class="h-4 w-6 overflow-hidden rounded-sm ring-1 ring-gray-900/10" aria-hidden="true"><path fill="#21468b" d="M0 0h24v16H0z"/><path stroke="#fff" stroke-width="3" d="m0 0 24 16M24 0 0 16"/><path stroke="#cf142b" stroke-width="1.5" d="m0 0 24 16M24 0 0 16"/><path fill="#fff" d="M10 0h4v16h-4zM0 6h24v4H0z"/><path fill="#cf142b" d="M11 0h2v16h-2zM0 7h24v2H0z"/></svg>
    </summary>
    <div class="absolute right-0 z-50 mt-2 w-44 rounded-xl border border-gray-200 bg-white p-2 shadow-theme-lg dark:border-gray-800 dark:bg-gray-900">
      <button type="button" class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-800" @click="chooseLanguage('id', $event)"><svg viewBox="0 0 24 16" class="h-4 w-6 overflow-hidden rounded-sm ring-1 ring-gray-900/10" aria-hidden="true"><path fill="#e70011" d="M0 0h24v8H0z"/><path fill="#fff" d="M0 8h24v8H0z"/></svg>Indonesia</button>
      <button type="button" class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-800" @click="chooseLanguage('en', $event)"><svg viewBox="0 0 24 16" class="h-4 w-6 overflow-hidden rounded-sm ring-1 ring-gray-900/10" aria-hidden="true"><path fill="#21468b" d="M0 0h24v16H0z"/><path stroke="#fff" stroke-width="3" d="m0 0 24 16M24 0 0 16"/><path stroke="#cf142b" stroke-width="1.5" d="m0 0 24 16M24 0 0 16"/><path fill="#fff" d="M10 0h4v16h-4zM0 6h24v4H0z"/><path fill="#cf142b" d="M11 0h2v16h-2zM0 7h24v2H0z"/></svg>English</button>
    </div>
  </details>
</template>
