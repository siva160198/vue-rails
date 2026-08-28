<script setup>
import { computed, onMounted, ref, watch } from "vue";
import { ArrowDown, ArrowUp, ChevronsUpDown, LoaderCircle, Search } from "@lucide/vue";
import { t } from "../services/i18n";
import SelectInput from "./SelectInput.vue";

const props = defineProps({
  items: { type: Array, default: () => [] },
  columns: { type: Array, required: true },
  loading: { type: Boolean, default: false },
  emptyText: { type: String, default: "" },
  searchable: { type: Boolean, default: true },
  searchKeys: { type: Array, default: () => [] },
  serverMode: { type: Boolean, default: false },
  total: { type: Number, default: 0 },
});
const emit = defineEmits(["request"]);
const query = ref("");
const page = ref(1);
const perPage = ref(10);
const sortKey = ref("");
const sortDirection = ref("asc");

const valueAt = (item, key) =>
  key.split(".").reduce((value, part) => value?.[part], item);
const filtered = computed(() => {
  const term = query.value.trim().toLowerCase();
  if (!term) return props.items;
  const keys = props.searchKeys.length
    ? props.searchKeys
    : props.columns.map((column) => column.key);
  return props.items.filter((item) =>
    keys.some((key) =>
      String(valueAt(item, key) ?? "")
        .toLowerCase()
        .includes(term),
    ),
  );
});
const sorted = computed(() => {
  if (!sortKey.value) return filtered.value;
  return [...filtered.value].sort(
    (left, right) =>
      String(valueAt(left, sortKey.value) ?? "").localeCompare(
        String(valueAt(right, sortKey.value) ?? ""),
        undefined,
        { numeric: true },
      ) * (sortDirection.value === "asc" ? 1 : -1),
  );
});
const resultTotal = computed(() =>
  props.serverMode ? props.total : sorted.value.length,
);
const totalPages = computed(() =>
  Math.max(1, Math.ceil(resultTotal.value / perPage.value)),
);
const rows = computed(() =>
  props.serverMode
    ? props.items
    : sorted.value.slice(
        (page.value - 1) * perPage.value,
        page.value * perPage.value,
      ),
);
const from = computed(() =>
  resultTotal.value ? (page.value - 1) * perPage.value + 1 : 0,
);
const to = computed(() =>
  Math.min(page.value * perPage.value, resultTotal.value),
);
let requestTimer;
function requestRows(delay = 0) {
  if (!props.serverMode) return;
  window.clearTimeout(requestTimer);
  requestTimer = window.setTimeout(
    () =>
      emit("request", {
        page: page.value,
        per_page: perPage.value,
        search: query.value,
        sort: sortKey.value,
        direction: sortDirection.value,
      }),
    delay,
  );
}
watch([query, perPage], ([next], [previous]) => {
  page.value = 1;
  requestRows(next !== previous ? 350 : 0);
});
watch(totalPages, () => {
  if (page.value > totalPages.value) page.value = totalPages.value;
});

function sort(column) {
  if (column.sortable === false) return;
  if (sortKey.value === column.key)
    sortDirection.value = sortDirection.value === "asc" ? "desc" : "asc";
  else {
    sortKey.value = column.key;
    sortDirection.value = "asc";
  }
  requestRows();
}
function changePage(value) {
  page.value = value;
  requestRows();
}
onMounted(() => requestRows());
</script>

<template>
  <div
    :aria-busy="loading"
    class="relative overflow-hidden rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]"
  >
    <div v-if="loading" role="status" :aria-label="t('table.loading')" class="absolute inset-0 z-20 flex cursor-wait items-center justify-center bg-white/75 backdrop-blur-[1px] dark:bg-gray-900/75">
      <div class="flex items-center gap-3 rounded-xl bg-white px-5 py-3 text-sm font-semibold text-gray-700 shadow-theme-lg ring-1 ring-gray-900/5 dark:bg-gray-900 dark:text-gray-200 dark:ring-white/10"><LoaderCircle :size="22" class="animate-spin text-brand-500" aria-hidden="true" />{{ t('table.loading') }}</div>
    </div>
    <div
      class="flex flex-col gap-3 border-b border-gray-200 p-4 dark:border-gray-800 sm:flex-row sm:items-center sm:justify-between"
    >
      <label class="flex items-center gap-2 text-sm text-gray-500"
        >{{ t("table.show")
        }}<SelectInput v-model="perPage">
          <option :value="5">5</option>
          <option :value="10">10</option>
          <option :value="25">25</option>
          <option :value="50">50</option></SelectInput
        >{{ t("table.entries") }}</label
      >
      <label v-if="searchable" class="relative"
        ><Search
          :size="17"
          class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" /><input
          v-model="query"
          type="search"
          :placeholder="t('table.search')"
          class="w-full rounded-lg py-2 pl-9 pr-3 text-sm sm:w-64"
      /></label>
    </div>
    <div class="max-w-full overflow-x-auto">
      <table class="min-w-full text-left text-sm">
        <thead
          class="bg-gray-50 text-xs uppercase text-gray-500 dark:bg-white/[0.02]"
        >
          <tr>
            <th v-for="column in columns" :key="column.key" class="px-5 py-3">
              <button
                type="button"
                :disabled="column.sortable === false"
                class="inline-flex items-center gap-1.5 font-semibold disabled:cursor-default"
                @click="sort(column)"
              >
                {{ column.label
                }}<component
                  :is="
                    sortKey === column.key
                      ? sortDirection === 'asc'
                        ? ArrowUp
                        : ArrowDown
                      : ChevronsUpDown
                  "
                  v-if="column.sortable !== false"
                  :size="14"
                />
              </button>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="item in rows"
            :key="item.id ?? JSON.stringify(item)"
            class="border-t border-gray-100 dark:border-gray-800"
          >
            <td v-for="column in columns" :key="column.key" class="px-5 py-4">
              <slot
                :name="`cell-${column.key}`"
                :item="item"
                :value="valueAt(item, column.key)"
                >{{ valueAt(item, column.key) }}</slot
              >
            </td>
          </tr>
        </tbody>
      </table>
      <p
        v-if="!loading && rows.length === 0"
        class="p-8 text-center text-sm text-gray-500"
      >
        {{ emptyText || t("table.empty") }}
      </p>
    </div>
    <div
      class="flex flex-col gap-3 border-t border-gray-200 p-4 text-sm text-gray-500 dark:border-gray-800 sm:flex-row sm:items-center sm:justify-between"
    >
      <p>{{ t("table.showing", { from, to, total: resultTotal }) }}</p>
      <div class="flex gap-2">
        <button
          type="button"
          :disabled="page === 1"
          class="rounded-lg border border-gray-200 px-3 py-2 font-medium disabled:opacity-40 dark:border-gray-700"
          @click="changePage(page - 1)"
        >
          {{ t("table.previous") }}</button
        ><span
          class="rounded-lg bg-brand-50 px-3 py-2 font-semibold text-brand-600 dark:bg-brand-500/10"
          >{{ page }} / {{ totalPages }}</span
        ><button
          type="button"
          :disabled="page === totalPages"
          class="rounded-lg border border-gray-200 px-3 py-2 font-medium disabled:opacity-40 dark:border-gray-700"
          @click="changePage(page + 1)"
        >
          {{ t("table.next") }}
        </button>
      </div>
    </div>
  </div>
</template>
