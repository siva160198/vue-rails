import { onBeforeUnmount, onMounted } from "vue";

export function useClickOutside(target, callback) {
  function handlePointerDown(event) {
    if (target.value && !target.value.contains(event.target)) callback(event);
  }

  onMounted(() => document.addEventListener("pointerdown", handlePointerDown));
  onBeforeUnmount(() => document.removeEventListener("pointerdown", handlePointerDown));
}
