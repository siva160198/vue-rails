import { describe, expect, it } from "vitest";
import {
  adminNavigation,
  adminRouteRecords,
  permittedAdminNavigation,
} from "./adminNavigation";

describe("adminNavigation", () => {
  it("builds lazy admin routes with permission metadata", () => {
    const routes = adminRouteRecords();
    const users = routes.find((route) => route.path === "/admin/users");

    expect(routes).toHaveLength(7);
    expect(users.meta).toEqual({ permission: "users.view", layout: "admin" });
    expect(users.component).toBeTypeOf("function");
  });

  it("removes unauthorized links and empty groups", () => {
    const visible = permittedAdminNavigation(["dashboard.view", "roles.view"]);
    const group = visible.find((item) => item.key === "user_management");

    expect(visible.map((item) => item.key)).toEqual(["dashboard", "user_management"]);
    expect(group.children.map((item) => item.key)).toEqual(["roles"]);
    expect(permittedAdminNavigation([], adminNavigation)).toEqual([]);
  });
});
