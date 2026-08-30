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

  function setError(field, message) {
    const messages = normalizeMessages(message);
    if (messages.length) errors.value = { ...errors.value, [field]: messages };
  }

  async function validate(rules, formElement) {
    errors.value = Object.fromEntries(
      Object.entries(rules)
        .map(([field, rule]) => [field, normalizeMessages(typeof rule === "function" ? rule() : rule)])
        .filter(([, messages]) => messages.length > 0),
    );
    return !(await focusFirstError(formElement));
  }

  async function focusFirstError(formElement) {
    const firstField = Object.keys(errors.value)[0];
    if (!firstField || !formElement) return false;
    await nextTick();
    formElement.elements?.namedItem(firstField)?.focus?.();
    return true;
  }

  async function applyApiError(error, formElement, fallbackField = "") {
    const mapped = Object.fromEntries(
      Object.entries(error?.details || {})
        .map(([field, messages]) => [field, normalizeMessages(messages)])
        .filter(([, messages]) => messages.length > 0),
    );
    errors.value = Object.keys(mapped).length || !fallbackField
      ? mapped
      : { [fallbackField]: normalizeMessages(error?.message) };

    return focusFirstError(formElement);
  }

  return { errors, errorFor, setError, clearError, clearErrors, validate, applyApiError };
}
