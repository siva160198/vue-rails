<script setup>
import { computed, nextTick, onBeforeUnmount, ref, useId, useSlots, watch } from "vue";
import { LoaderCircle, X } from "@lucide/vue";
import { t } from "../services/i18n";

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, required: true },
  hint: { type: String, default: "" },
  loading: { type: Boolean, default: false },
  closeDisabled: { type: Boolean, default: false },
  size: { type: String, default: "lg" },
});
const emit = defineEmits(["close"]);
const slots = useSlots();
const titleId = `modal-title-${useId()}`;
const modalId = Symbol("modal");
const sizes = { sm: "max-w-md", md: "max-w-xl", lg: "max-w-3xl", xl: "max-w-5xl" };
const widthClass = computed(() => sizes[props.size] || sizes.lg);
const dialogElement = ref(null);
let previouslyFocusedElement = null;

const modalStack = globalThis.__vue_railsModalStack || [];
globalThis.__vue_railsModalStack = modalStack;

function isTopModal() {
  return modalStack.at(-1) === modalId;
}

function requestClose() {
  if (!props.closeDisabled && !props.loading && isTopModal()) emit("close");
}

function handleKeydown(event) {
  if (!props.open || !isTopModal()) return;
  if (event.key === "Escape") requestClose();
  if (event.key !== "Tab" || !dialogElement.value) return;

  const focusable = [...dialogElement.value.querySelectorAll(
    'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
  )].filter((element) => !element.hidden);
  if (focusable.length === 0) {
    event.preventDefault();
    dialogElement.value.focus();
    return;
  }

  const first = focusable[0];
  const last = focusable.at(-1);
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

watch(
  () => props.open,
  async (open, wasOpen) => {
    const index = modalStack.indexOf(modalId);
    if (open && index === -1) {
      previouslyFocusedElement = document.activeElement;
      modalStack.push(modalId);
      await nextTick();
      const firstFocusable = dialogElement.value?.querySelector(
        'button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), a[href]',
      );
      (firstFocusable || dialogElement.value)?.focus();
    }
    if (!open && index >= 0) {
      modalStack.splice(index, 1);
      if (wasOpen && previouslyFocusedElement?.isConnected) previouslyFocusedElement.focus();
      previouslyFocusedElement = null;
    }
    document.body.classList.toggle("overflow-hidden", modalStack.length > 0);
  },
  { immediate: true },
);

document.addEventListener("keydown", handleKeydown);
onBeforeUnmount(() => {
  document.removeEventListener("keydown", handleKeydown);
  const index = modalStack.indexOf(modalId);
  if (index >= 0) modalStack.splice(index, 1);
  document.body.classList.toggle("overflow-hidden", modalStack.length > 0);
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-[240] flex items-center justify-center bg-gray-950/50 p-4 backdrop-blur-sm"
      @click.self="requestClose"
    >
      <section
        ref="dialogElement"
        role="dialog"
        tabindex="-1"
        aria-modal="true"
        :aria-labelledby="titleId"
        :aria-busy="loading"
        :class="widthClass"
        class="flex max-h-[90vh] w-full flex-col overflow-hidden rounded-2xl bg-white shadow-theme-lg dark:bg-gray-900"
      >
        <header
          class="flex items-start justify-between border-b border-gray-200 p-5 dark:border-gray-800"
        >
          <div class="min-w-0">
            <h2
              :id="titleId"
              class="text-lg font-semibold text-gray-900 dark:text-white"
            >
              {{ title }}
            </h2>
            <p v-if="hint" class="mt-1 truncate text-sm text-gray-500">
              {{ hint }}
            </p>
          </div>
          <button
            type="button"
            :disabled="closeDisabled || loading"
            :aria-label="t('common.close')"
            class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-60 dark:hover:bg-gray-800"
            @click="requestClose"
          >
            <X :size="20" />
          </button>
        </header>

        <div
          v-if="loading"
          role="status"
          :aria-label="t('common.loading_data')"
          class="flex min-h-64 items-center justify-center p-8"
        >
          <div class="flex items-center gap-3 text-sm font-semibold text-gray-600 dark:text-gray-300">
            <LoaderCircle :size="24" class="animate-spin text-brand-500" />
            {{ t("common.loading_data") }}
          </div>
        </div>
        <div v-else class="overflow-y-auto p-5">
          <slot />
        </div>

        <footer
          v-if="!loading && slots.footer"
          class="flex justify-end gap-3 border-t border-gray-200 p-4 dark:border-gray-800"
        >
          <slot name="footer" />
        </footer>
      </section>
    </div>
  </Teleport>
</template>
