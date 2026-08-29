<script setup>
import { computed } from "vue";
import { Pencil, Save, Trash2 } from "@lucide/vue";
import AsyncButton from "./AsyncButton.vue";

const props = defineProps({
  action: { type: String, required: true },
  label: { type: String, required: true },
  accessibleLabel: { type: String, default: "" },
  loadingText: { type: String, default: "" },
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});
const icons = { edit: Pencil, save: Save, delete: Trash2 };
const icon = computed(() => icons[props.action] || Pencil);
const danger = computed(() => props.action === "delete");
</script>

<template>
  <AsyncButton
    :loading="loading"
    :disabled="disabled"
    :loading-text="loadingText || label"
    :aria-label="accessibleLabel || label"
    :title="accessibleLabel || label"
    class="h-9 w-9 rounded-lg border text-xs font-semibold xl:h-auto xl:w-auto xl:gap-1.5 xl:px-3 xl:py-2"
    :class="
      danger
        ? 'border-error-200 text-error-700 hover:bg-error-50'
        : 'border-gray-200 text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
    "
  >
    <component :is="icon" :size="14" />
    <span class="hidden xl:inline">{{ label }}</span>
  </AsyncButton>
</template>
