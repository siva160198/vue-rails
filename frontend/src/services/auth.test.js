import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiFetch, currentUser } from "./api";
import { resetAuthState, useAuth } from "./auth";

vi.mock("./api", () => ({ apiFetch: vi.fn(), currentUser: vi.fn() }));

describe("useAuth", () => {
  beforeEach(() => {
    resetAuthState();
    vi.resetAllMocks();
  });

  it("deduplicates and caches current-user requests", async () => {
    currentUser.mockResolvedValue({
      id: 1,
      permissions: ["users.view", "users.update"],
    });
    const auth = useAuth();

    const [first, second] = await Promise.all([
      auth.loadUser(),
      auth.loadUser(),
    ]);
    const cached = await auth.loadUser();

    expect(currentUser).toHaveBeenCalledTimes(1);
    expect(first).toEqual(second);
    expect(cached).toEqual(first);
    expect(auth.can("users.update")).toBe(true);
    expect(auth.canAny(["roles.view", "users.view"])).toBe(true);
  });

  it("clears the shared user after logout", async () => {
    apiFetch.mockResolvedValue(null);
    const auth = useAuth();
    auth.setUser({ id: 1, permissions: [] });

    await auth.logout();

    expect(apiFetch).toHaveBeenCalledWith("/api/v1/session", {
      method: "DELETE",
    });
    expect(auth.user.value).toBeNull();
  });
});
