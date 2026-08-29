<script setup>
import { defineAsyncComponent } from 'vue'
import { useRoute } from 'vue-router'
import { appError } from './services/errorState'
import ToastContainer from './components/ToastContainer.vue'
import NavigationLoader from './components/NavigationLoader.vue'
import { t } from './services/i18n'
import LanguageSwitcher from './components/LanguageSwitcher.vue'

const route = useRoute()
const AppErrorView = defineAsyncComponent(() => import('./views/AppErrorView.vue'))
</script>

<template>
  <div class="min-h-screen bg-slate-50 text-slate-900">
    <header v-if="route.meta.layout !== 'admin'" class="border-b border-slate-200 bg-white">
      <nav class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <RouterLink to="/" class="text-xl font-bold tracking-tight">Vue Rails</RouterLink>
        <div class="flex items-center gap-5 text-sm font-medium">
          <RouterLink to="/" class="hover:text-brand-600">{{ t('nav.home') }}</RouterLink>
          <RouterLink to="/admin" class="hover:text-brand-600">{{ t('nav.admin') }}</RouterLink>
          <LanguageSwitcher />
        </div>
      </nav>
    </header>
    <AppErrorView v-if="appError" />
    <RouterView v-else />
    <ToastContainer />
    <NavigationLoader />
  </div>
</template>
