<script setup>
import ErrorPage from '../components/ErrorPage.vue'
import { t } from '../services/i18n'
</script>

<template>
  <ErrorPage
    code="404"
    :title="t('error.404_title')"
    :message="t('error.404_message')"
  />
</template>
