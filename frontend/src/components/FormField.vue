<script setup>
import { computed, provide, useId } from "vue";
import { formFieldContextKey } from "./formFieldContext";

const props = defineProps({
  label: { type: String, required: true },
  forId: { type: String, default: "" },
  help: { type: String, default: "" },
  error: { type: [String, Array], default: "" },
});
const generatedId = useId();
const hasError = computed(() => Array.isArray(props.error) ? props.error.length > 0 : Boolean(props.error));
const controlId = computed(() => props.forId || `field-${generatedId}`);
const helpId = computed(() => (props.help ? `${controlId.value}-help` : undefined));
const errorId = computed(() => (hasError.value ? `${controlId.value}-error` : undefined));
const describedBy = computed(() => [helpId.value, errorId.value].filter(Boolean).join(" ") || undefined);

provide(formFieldContextKey, {
  controlId,
  describedBy,
  invalid: hasError,
});
</script>

<template>
  <div>
    <label :for="controlId" class="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-200">
      {{ label }}
    </label>
    <slot />
    <p v-if="help" :id="helpId" class="mt-1.5 text-xs text-gray-500">{{ help }}</p>
    <p v-if="hasError" :id="errorId" role="alert" class="mt-1.5 text-xs text-error-700">
      {{ Array.isArray(error) ? error.join(", ") : error }}
    </p>
    <slot name="after" />
  </div>
</template>
