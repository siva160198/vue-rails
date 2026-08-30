<script setup>
import { inject, useAttrs } from "vue";
import { formFieldContextKey } from "./formFieldContext";

defineOptions({ inheritAttrs: false });
const attrs = useAttrs();
const field = inject(formFieldContextKey, null);
const model = defineModel({ type: String, default: "" });
</script>

<template>
  <textarea
    v-bind="attrs"
    v-model="model"
    :id="attrs.id || field?.controlId.value"
    :aria-describedby="attrs['aria-describedby'] || field?.describedBy.value"
    :aria-invalid="attrs['aria-invalid'] ?? field?.invalid.value"
    class="w-full resize-y rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-900 shadow-sm aria-[invalid=true]:border-error-500 aria-[invalid=true]:ring-4 aria-[invalid=true]:ring-error-100 dark:border-gray-700 dark:bg-gray-900 dark:text-white dark:aria-[invalid=true]:border-error-600 dark:aria-[invalid=true]:ring-error-500/15"
  />
</template>
