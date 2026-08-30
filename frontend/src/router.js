import { createRouter, createWebHistory } from "vue-router";
import { useAuth } from "./services/auth";
import { toast } from "./services/toast";
import {
  finishNavigationLoading,
  startNavigationLoading,
} from "./services/navigationLoading";
import { t } from "./services/i18n";

const HomeView = () => import("./views/HomeView.vue");
const LoginView = () => import("./views/LoginView.vue");
const ForgotPasswordView = () => import("./views/ForgotPasswordView.vue");
const ResetPasswordView = () => import("./views/ResetPasswordView.vue");
const EmailRevertView = () => import("./views/EmailRevertView.vue");
const RegisterView = () => import("./views/RegisterView.vue");
const AdminView = () => import("./views/AdminView.vue");
const AdminUsersView = () => import("./views/AdminUsersView.vue");
const AdminAuditLogsView = () => import("./views/AdminAuditLogsView.vue");
const AdminRolesView = () => import("./views/AdminRolesView.vue");
const ProfileView = () => import("./views/ProfileView.vue");
const AdminJobsView = () => import("./views/AdminJobsView.vue");
const AdminApiDocsView = () => import("./views/AdminApiDocsView.vue");
const AdminApprovalsView = () => import("./views/AdminApprovalsView.vue");
const ForbiddenView = () => import("./views/ForbiddenView.vue");
const NotFoundView = () => import("./views/NotFoundView.vue");
const AppErrorView = () => import("./views/AppErrorView.vue");
const { loadUser, can } = useAuth();

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/login", component: LoginView },
    { path: "/forgot-password", component: ForgotPasswordView },
    { path: "/reset-password", component: ResetPasswordView },
    { path: "/email-revert", component: EmailRevertView },
    { path: "/register", component: RegisterView },
    { path: "/403", component: ForbiddenView },
    { path: "/error", component: AppErrorView },
    {
      path: "/admin",
      component: AdminView,
      meta: { permission: "dashboard.view", layout: "admin" },
    },
    {
      path: "/admin/users",
      component: AdminUsersView,
      meta: { permission: "users.view", layout: "admin" },
    },
    {
      path: "/admin/roles",
      component: AdminRolesView,
      meta: { permission: "roles.view", layout: "admin" },
    },
    {
      path: "/admin/audit-logs",
      component: AdminAuditLogsView,
      meta: { permission: "audit_logs.view", layout: "admin" },
    },
    { path: "/admin/sessions", redirect: "/profile" },
    { path: "/account/security", redirect: "/profile" },
    { path: "/profile", component: ProfileView, meta: { permission: "profile.view", layout: "admin" } },
    { path: "/admin/jobs", component: AdminJobsView, meta: { permission: "jobs.view", layout: "admin" } },
    { path: "/admin/api-docs", component: AdminApiDocsView, meta: { permission: "api_docs.view", layout: "admin" } },
    { path: "/admin/security-approvals", component: AdminApprovalsView, meta: { permission: "security_approvals.view", layout: "admin" } },
    { path: "/:pathMatch(.*)*", component: NotFoundView },
  ],
});

router.beforeEach(async (to) => {
  startNavigationLoading();
  if (!to.meta.permission) return true;
  const user = await loadUser();
  if (!user) {
    toast.warning(t("auth.login_required"));
    return { path: "/login", query: { redirect: to.fullPath } };
  }
  if (!can(to.meta.permission)) return { path: "/403" };
  return true;
});

router.afterEach(() => finishNavigationLoading());

router.onError((error) => {
  finishNavigationLoading();
  console.error("Vue Router error:", error);
  if (router.currentRoute.value.path !== "/error") router.replace("/error");
});

export default router;
