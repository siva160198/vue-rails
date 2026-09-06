import { adminRouteRecords } from "../config/adminNavigation";

export function authenticatedLandingPath(permissions = []) {
  const allowed = new Set(permissions);
  const adminRoute = adminRouteRecords().find((route) =>
    allowed.has(route.meta.permission),
  );

  if (adminRoute) return adminRoute.path;
  if (allowed.has("profile.view")) return "/profile";
  return "/";
}
