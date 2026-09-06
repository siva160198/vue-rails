import { describe, expect, it } from "vitest";
import router from "./router";

describe("router access metadata", () => {
  it.each([
    "/login",
    "/register",
    "/forgot-password",
    "/reset-password",
  ])("marks %s as guest-only", (path) => {
    const route = router.getRoutes().find((entry) => entry.path === path);

    expect(route.meta.guestOnly).toBe(true);
  });

  it("keeps the home page public", () => {
    const home = router.getRoutes().find((entry) => entry.path === "/");

    expect(home.meta.guestOnly).toBeUndefined();
    expect(home.meta.permission).toBeUndefined();
  });
});
