import { nextTick, ref } from "vue";

function normalizeMessages(value) {
  if (Array.isArray(value)) return value.filter(Boolean).map(String);
  return value ? [String(value)] : [];
}

export function useFormErrors() {
  const errors = ref({});

  function errorFor(field) {
    return errors.value[field] || [];
  }

  function clearError(field) {
    if (!errors.value[field]) return;
    const nextErrors = { ...errors.value };
    delete nextErrors[field];
    errors.value = nextErrors;
  }

  function clearErrors() {
    errors.value = {};
  }

  async function applyApiError(error, formElement) {
    errors.value = Object.fromEntries(
      Object.entries(error?.details || {})
        .map(([field, messages]) => [field, normalizeMessages(messages)])
        .filter(([, messages]) => messages.length > 0),
    );

    const firstField = Object.keys(errors.value)[0];
    if (!firstField || !formElement) return false;
    await nextTick();
    formElement.elements?.namedItem(firstField)?.focus?.();
    return true;
  }

  return { errors, errorFor, clearError, clearErrors, applyApiError };
}
