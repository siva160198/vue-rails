<script setup>
import { inject, useAttrs } from "vue";
import { formFieldContextKey } from "./formFieldContext";

defineOptions({ inheritAttrs: false });
const attrs = useAttrs();
const field = inject(formFieldContextKey, null);
const emit = defineEmits(["change"]);
</script>

<template><input v-bind="attrs" type="file" :id="attrs.id || field?.controlId.value" :aria-describedby="attrs['aria-describedby'] || field?.describedBy.value" :aria-invalid="attrs['aria-invalid'] ?? field?.invalid.value" class="block w-full rounded-lg border border-gray-300 bg-white text-sm text-gray-700 file:mr-4 file:border-0 file:bg-brand-50 file:px-4 file:py-2.5 file:font-medium file:text-brand-700 hover:file:bg-brand-100 disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300" @change="emit('change', $event)" /></template>
