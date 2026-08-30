import { ref } from "vue";
import { apiFetch } from "./api";
import { toast } from "./toast";

export function useServerTable({ endpoint, collectionKey, onResponse } = {}) {
  const items = ref([]);
  const loading = ref(false);
  const pagination = ref({ page: 1, per_page: 10, total: null, total_pages: 1, next_cursor: null, previous_cursor: null, has_next: false, has_previous: false });
  let requestSequence = 0;
  let activeController;

  async function load(options = { page: 1, per_page: 10 }) {
    const sequence = ++requestSequence;
    activeController?.abort();
    activeController = new AbortController();
    const controller = activeController;
    loading.value = true;
    const query = new URLSearchParams(
      Object.entries(options).filter(
        ([, value]) => value !== "" && value != null,
      ),
    ).toString();
    const url = typeof endpoint === "function" ? endpoint(options) : endpoint;

    try {
      const response = await apiFetch(query ? `${url}?${query}` : url, { signal: controller.signal });
      if (sequence !== requestSequence) return response;

      items.value = response[collectionKey] || [];
      pagination.value = {
        page: response.pagination?.page || 1,
        per_page: response.pagination?.per_page || 10,
        total: response.pagination?.total ?? null,
        total_pages: response.pagination?.total_pages || 1,
        next_cursor: response.pagination?.next_cursor || null,
        previous_cursor: response.pagination?.previous_cursor || null,
        has_next: Boolean(response.pagination?.has_next),
        has_previous: Boolean(response.pagination?.has_previous),
      };
      onResponse?.(response);
      return response;
    } catch (requestError) {
      if (sequence === requestSequence && requestError.code !== "REQUEST_ABORTED") toast.error(requestError.message);
      return undefined;
    } finally {
      if (sequence === requestSequence) {
        loading.value = false;
        activeController = undefined;
      }
    }
  }

  function updateItem(id, value) {
    const index = items.value.findIndex((item) => item.id === id);
    if (index >= 0) items.value[index] = value;
  }

  function removeItem(id) {
    items.value = items.value.filter((item) => item.id !== id);
    if (pagination.value.total == null) return;
    const total = Math.max(0, pagination.value.total - 1);
    pagination.value = {
      ...pagination.value,
      total,
      total_pages: Math.max(1, Math.ceil(total / pagination.value.per_page)),
    };
  }

  return { items, loading, pagination, load, updateItem, removeItem };
}
