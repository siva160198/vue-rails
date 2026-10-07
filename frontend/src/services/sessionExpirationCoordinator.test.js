import { beforeEach, describe, expect, it, vi } from "vitest";
import { ref } from "vue";
import { notifyAuthenticationRequired, resetAuthenticationRequiredHandler } from "./sessionExpiration";
import { installSessionExpirationHandler } from "./sessionExpirationCoordinator";
import { clearSessionLock, lockedAccount } from "./sessionLock";

describe("session expiration coordinator", () => {
  beforeEach(() => { resetAuthenticationRequiredHandler(); clearSessionLock(); });

  it("keeps the page and user mounted behind one lock screen", () => {
    const auth = { user: ref({ id: 1, unlock_token: 'context' }), clearUser: vi.fn() };
    const router = { replace: vi.fn() };
    const notify = vi.fn();
    installSessionExpirationHandler({ router, auth, notify, translate: (key) => key });
    notifyAuthenticationRequired(); notifyAuthenticationRequired();
    expect(lockedAccount.value.id).toBe(1);
    expect(notify).toHaveBeenCalledOnce();
    expect(auth.clearUser).not.toHaveBeenCalled();
    expect(router.replace).not.toHaveBeenCalled();
  });

  it("clears auth, toasts once, and preserves the current destination", async () => {
    const auth = { user: ref({ id: 1 }), clearUser: vi.fn(() => { auth.user.value = null; }) };
    const router = { currentRoute: ref({ path: "/admin/users", fullPath: "/admin/users?page=2" }), replace: vi.fn().mockResolvedValue(undefined) };
    const notify = vi.fn();
    installSessionExpirationHandler({ router, auth, notify, translate: () => "Sesi berakhir", schedule: (callback) => callback() });

    notifyAuthenticationRequired();
    notifyAuthenticationRequired();
    await vi.waitFor(() => expect(router.replace).toHaveBeenCalledOnce());

    expect(auth.clearUser).toHaveBeenCalledOnce();
    expect(notify).toHaveBeenCalledWith("Sesi berakhir");
    expect(router.replace).toHaveBeenCalledWith({ path: "/login", query: { redirect: "/admin/users?page=2" } });
  });

  it("ignores authentication errors when no user was signed in", () => {
    const router = { currentRoute: ref({ path: "/", fullPath: "/" }), replace: vi.fn() };
    installSessionExpirationHandler({ router, auth: { user: ref(null), clearUser: vi.fn() }, notify: vi.fn(), translate: vi.fn() });
    notifyAuthenticationRequired();
    expect(router.replace).not.toHaveBeenCalled();
  });
});
