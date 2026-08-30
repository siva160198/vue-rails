import { beforeEach, describe, expect, it, vi } from "vitest";
import { notifyAuthenticationRequired, registerAuthenticationRequiredHandler, resetAuthenticationRequiredHandler } from "./sessionExpiration";

describe("session expiration events", () => {
  beforeEach(resetAuthenticationRequiredHandler);

  it("notifies the active handler and supports unregistering it", () => {
    const handler = vi.fn();
    const unregister = registerAuthenticationRequiredHandler(handler);
    notifyAuthenticationRequired({ code: "AUTHENTICATION_REQUIRED" });
    expect(handler).toHaveBeenCalledOnce();
    unregister();
    notifyAuthenticationRequired({ code: "AUTHENTICATION_REQUIRED" });
    expect(handler).toHaveBeenCalledOnce();
  });
});
