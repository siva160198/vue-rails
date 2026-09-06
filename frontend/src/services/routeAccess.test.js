import { describe, expect, it } from "vitest";
import { authenticatedLandingPath } from "./routeAccess";

describe("authenticatedLandingPath", () => {
  it("prefers the first permitted admin page", () => {
    expect(authenticatedLandingPath(["roles.view", "profile.view"])).toBe(
      "/admin/roles",
    );
    expect(authenticatedLandingPath(["dashboard.view"])).toBe("/admin");
  });

  it("falls back safely without sending users to a forbidden page", () => {
    expect(authenticatedLandingPath(["profile.view"])).toBe("/profile");
    expect(authenticatedLandingPath([])).toBe("/");
  });
});
