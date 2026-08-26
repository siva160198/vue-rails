<script setup>
import ErrorPage from '../components/ErrorPage.vue'
import { clearAppError } from '../services/errorState'

function retry() {
  clearAppError()
  window.location.reload()
}
</script>

<template>
  <ErrorPage
    code="500"
    title="Terjadi kesalahan"
    message="Aplikasi mengalami kendala yang tidak terduga. Silakan coba muat ulang halaman."
    show-retry
    @retry="retry"
  />
</template>
