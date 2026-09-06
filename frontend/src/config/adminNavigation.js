import {
  BookOpen,
  BriefcaseBusiness,
  ClipboardCheck,
  LayoutDashboard,
  ScrollText,
  ShieldCheck,
  Users,
} from "@lucide/vue";

export const adminNavigation = [
  {
    key: "dashboard",
    labelKey: "nav.dashboard",
    icon: LayoutDashboard,
    path: "/admin",
    permission: "dashboard.view",
    component: () => import("../views/AdminView.vue"),
  },
  {
    key: "user_management",
    labelKey: "nav.user_management",
    icon: Users,
    children: [
      {
        key: "users",
        labelKey: "nav.users",
        icon: Users,
        path: "/admin/users",
        permission: "users.view",
        component: () => import("../views/AdminUsersView.vue"),
      },
      {
        key: "roles",
        labelKey: "nav.roles",
        icon: ShieldCheck,
        path: "/admin/roles",
        permission: "roles.view",
        component: () => import("../views/AdminRolesView.vue"),
      },
    ],
  },
  {
    key: "audit_logs",
    labelKey: "nav.audit_logs",
    icon: ScrollText,
    path: "/admin/audit-logs",
    permission: "audit_logs.view",
    component: () => import("../views/AdminAuditLogsView.vue"),
  },
  {
    key: "jobs",
    labelKey: "nav.jobs",
    icon: BriefcaseBusiness,
    path: "/admin/jobs",
    permission: "jobs.view",
    component: () => import("../views/AdminJobsView.vue"),
  },
  {
    key: "api_docs",
    labelKey: "nav.api_docs",
    icon: BookOpen,
    path: "/admin/api-docs",
    permission: "api_docs.view",
    component: () => import("../views/AdminApiDocsView.vue"),
  },
  {
    key: "security_approvals",
    labelKey: "nav.security_approvals",
    icon: ClipboardCheck,
    path: "/admin/security-approvals",
    permission: "security_approvals.view",
    component: () => import("../views/AdminApprovalsView.vue"),
  },
];

export function adminRouteRecords(items = adminNavigation) {
  return items.flatMap((item) => {
    if (item.children) return adminRouteRecords(item.children);
    return [{
      path: item.path,
      component: item.component,
      meta: { permission: item.permission, layout: "admin" },
    }];
  });
}

export function permittedAdminNavigation(permissions, items = adminNavigation) {
  const allowed = new Set(permissions);

  return items.flatMap((item) => {
    if (item.permission && !allowed.has(item.permission)) return [];
    if (!item.children) return [item];

    const children = permittedAdminNavigation(permissions, item.children);
    return children.length ? [{ ...item, children }] : [];
  });
}
