<script setup>
import { defineAsyncComponent } from 'vue'
import { useRoute } from 'vue-router'
import { appError } from './services/errorState'
import ToastContainer from './components/ToastContainer.vue'
import NavigationLoader from './components/NavigationLoader.vue'
import { locale, setLocale, t } from './services/i18n'

const route = useRoute()
const AppErrorView = defineAsyncComponent(() => import('./views/AppErrorView.vue'))
</script>

<template>
  <div class="min-h-screen bg-slate-50 text-slate-900">
    <header v-if="route.meta.layout !== 'admin'" class="border-b border-slate-200 bg-white">
      <nav class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <RouterLink to="/" class="text-xl font-bold tracking-tight">Tourplan</RouterLink>
        <div class="flex items-center gap-5 text-sm font-medium">
          <RouterLink to="/" class="hover:text-brand-600">{{ t('nav.home') }}</RouterLink>
          <RouterLink to="/admin" class="hover:text-brand-600">{{ t('nav.admin') }}</RouterLink>
          <details class="group relative">
            <summary :aria-label="t('nav.language')" class="flex size-9 cursor-pointer list-none items-center justify-center rounded-lg border border-gray-200 bg-white text-xl hover:bg-gray-50">{{ locale === 'id' ? '🇮🇩' : '🇬🇧' }}</summary>
            <div class="absolute right-0 z-50 mt-2 w-40 rounded-xl border border-gray-200 bg-white p-2 shadow-theme-lg">
              <button type="button" class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm hover:bg-gray-50" @click="setLocale('id'); $event.currentTarget.closest('details').removeAttribute('open')"><span class="text-xl">🇮🇩</span>Indonesia</button>
              <button type="button" class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm hover:bg-gray-50" @click="setLocale('en'); $event.currentTarget.closest('details').removeAttribute('open')"><span class="text-xl">🇬🇧</span>English</button>
            </div>
          </details>
        </div>
      </nav>
    </header>
    <AppErrorView v-if="appError" />
    <RouterView v-else />
    <ToastContainer />
    <NavigationLoader />
  </div>
</template>
