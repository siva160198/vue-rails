<script setup>
import ErrorPage from '../components/ErrorPage.vue'
import { t } from '../services/i18n'
</script>

<template>
  <ErrorPage
    code="403"
    :title="t('error.403_title')"
    :message="t('error.403_message')"
  />
</template>
