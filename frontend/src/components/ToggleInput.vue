<script setup>
defineProps({
  label: { type: String, required: true },
  hint: { type: String, default: "" },
  disabled: { type: Boolean, default: false },
});
const model = defineModel({ type: Boolean, default: false });
</script>

<template>
  <label
    class="flex items-center justify-between gap-4 rounded-xl border border-gray-200 p-4 dark:border-gray-700"
    :class="disabled ? 'cursor-not-allowed opacity-60' : 'cursor-pointer'"
  >
    <span>
      <strong class="block text-sm font-medium text-gray-900 dark:text-white">{{ label }}</strong>
      <small v-if="hint" class="mt-1 block text-xs text-gray-500">{{ hint }}</small>
    </span>
    <input v-model="model" type="checkbox" class="peer sr-only" :disabled="disabled" />
    <span
      class="relative block h-6 w-11 shrink-0 rounded-full bg-gray-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-transform peer-checked:bg-brand-500 peer-checked:after:translate-x-5"
    ></span>
  </label>
</template>
