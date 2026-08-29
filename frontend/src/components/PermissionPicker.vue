<script setup>
import { computed, ref } from "vue";
import { ChevronRight } from "@lucide/vue";
import { t } from "../services/i18n";
import AppModal from "./AppModal.vue";
const props = defineProps({
  permissions: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
  readonly: { type: Boolean, default: false },
});
const selected = defineModel({ type: Array, default: () => [] });
const modalOpen = ref(false);
const preview = computed(() => props.permissions.slice(0, 5));
const remaining = computed(() => Math.max(0, props.permissions.length - 5));

function permissionText(permission, field) {
  const key = `permission.${permission.key}.${field}`;
  const translated = t(key);
  return translated === key ? permission[field] : translated;
}
</script>
<template>
  <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
    <label
      v-for="permission in preview"
      :key="permission.key"
      class="flex items-start gap-2 rounded-lg border border-gray-200 p-2.5 text-xs dark:border-gray-700"
      :class="readonly ? 'cursor-default' : 'cursor-pointer'"
      ><input
        v-model="selected"
        type="checkbox"
        :value="permission.key"
        :disabled="disabled || readonly"
        class="mt-0.5"
      /><span
        ><strong class="block text-gray-800 dark:text-white">{{
          permissionText(permission, "name")
        }}</strong
        ><small class="mt-0.5 block text-gray-500">{{
          permissionText(permission, "description")
        }}</small></span
      ></label
    >
    <button
      v-if="remaining"
      type="button"
      :disabled="disabled"
      class="flex min-h-16 items-center justify-between rounded-lg border border-dashed border-gray-300 p-3 text-left text-sm font-semibold text-brand-600 hover:border-brand-400 hover:bg-brand-50 disabled:opacity-50 dark:border-gray-700 dark:hover:bg-brand-500/10"
      @click="modalOpen = true"
    >
      {{ t("roles.more", { count: remaining }) }}<ChevronRight :size="18" />
    </button>
  </div>
  <AppModal
    :open="modalOpen"
    :title="t('roles.permission_modal_title')"
    :hint="t('roles.permission_modal_hint')"
    @close="modalOpen = false"
  >
    <div class="grid max-h-[60vh] gap-3 sm:grid-cols-2">
      <label
        v-for="permission in permissions"
        :key="permission.key"
        class="flex items-start gap-3 rounded-xl border border-gray-200 p-3 dark:border-gray-700"
        :class="readonly ? 'cursor-default' : 'cursor-pointer'"
        ><input
          v-model="selected"
          type="checkbox"
          :value="permission.key"
          :disabled="disabled || readonly"
          class="mt-1"
        /><span
          ><strong class="block text-sm text-gray-900 dark:text-white">{{
            permissionText(permission, "name")
          }}</strong
          ><small class="text-gray-500">{{
            permissionText(permission, "description")
          }}</small></span
        ></label
      >
    </div>
    <template #footer>
      <button
        type="button"
        class="rounded-lg bg-brand-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-600"
        @click="modalOpen = false"
      >
        {{ t("common.done") }}
      </button>
    </template>
  </AppModal>
</template>
