<script setup>
import ErrorPage from '../components/ErrorPage.vue'
import { clearAppError } from '../services/errorState'
import { t } from '../services/i18n'

function retry() {
  clearAppError()
  window.location.reload()
}
</script>

<template>
  <ErrorPage
    code="500"
    :title="t('error.500_title')"
    :message="t('error.500_message')"
    show-retry
    @retry="retry"
  />
</template>
