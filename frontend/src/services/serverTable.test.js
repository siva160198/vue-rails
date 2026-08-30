import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiFetch } from "./api";
import { toast } from "./toast";
import { useServerTable } from "./serverTable";

vi.mock("./api", () => ({ apiFetch: vi.fn() }));
vi.mock("./toast", () => ({ toast: { error: vi.fn() } }));

describe("useServerTable", () => {
  beforeEach(() => vi.resetAllMocks());

  it("serializes table options and stores standardized pagination", async () => {
    apiFetch.mockResolvedValue({
      users: [{ id: 1 }],
      pagination: { page: 2, per_page: 5, total: 6, total_pages: 2 },
    });
    const table = useServerTable({
      endpoint: "/api/v1/admin/users",
      collectionKey: "users",
    });

    await table.load({ page: 2, per_page: 5, search: "member" });

    expect(apiFetch).toHaveBeenCalledWith(
      "/api/v1/admin/users?page=2&per_page=5&search=member",
      { signal: expect.any(AbortSignal) },
    );
    expect(table.items.value).toEqual([{ id: 1 }]);
    expect(table.pagination.value).toEqual({
      page: 2,
      per_page: 5,
      total: 6,
      total_pages: 2,
      next_cursor: null,
      previous_cursor: null,
      has_next: false,
      has_previous: false,
    });

    table.updateItem(1, { id: 1, active: false });
    expect(table.items.value).toEqual([{ id: 1, active: false }]);
    table.removeItem(1);
    expect(table.items.value).toEqual([]);
    expect(table.pagination.value.total).toBe(5);
    expect(table.pagination.value.total_pages).toBe(1);
  });

  it("ignores stale responses from older requests", async () => {
    let resolveFirst;
    let resolveSecond;
    apiFetch
      .mockReturnValueOnce(new Promise((resolve) => (resolveFirst = resolve)))
      .mockReturnValueOnce(new Promise((resolve) => (resolveSecond = resolve)));
    const table = useServerTable({
      endpoint: "/users",
      collectionKey: "users",
    });

    const first = table.load({ search: "old" });
    const second = table.load({ search: "new" });
    resolveSecond({
      users: [{ id: 2 }],
      pagination: { page: 1, per_page: 10, total: 1, total_pages: 1 },
    });
    await second;
    resolveFirst({
      users: [{ id: 1 }],
      pagination: { page: 1, per_page: 10, total: 1, total_pages: 1 },
    });
    await first;

    expect(table.items.value).toEqual([{ id: 2 }]);
    expect(table.loading.value).toBe(false);
    expect(toast.error).not.toHaveBeenCalled();
  });

  it("aborts the previous in-flight request", async () => {
    apiFetch.mockImplementation((_url, { signal }) => new Promise((_resolve, reject) => {
      signal.addEventListener("abort", () => reject(Object.assign(new Error("cancelled"), { code: "REQUEST_ABORTED" })), { once: true });
    }));
    const table = useServerTable({ endpoint: "/users", collectionKey: "users" });

    const first = table.load({ search: "old" });
    table.load({ search: "new" });
    await first;

    expect(toast.error).not.toHaveBeenCalled();
  });
});
