import { createRouter, createWebHistory } from "vue-router";
import { useAuth } from "./services/auth";
import { toast } from "./services/toast";
import {
  finishNavigationLoading,
  startNavigationLoading,
} from "./services/navigationLoading";
import { t } from "./services/i18n";
import { adminRouteRecords } from "./config/adminNavigation";
import { authenticatedLandingPath } from "./services/routeAccess";

const HomeView = () => import("./views/HomeView.vue");
const LoginView = () => import("./views/LoginView.vue");
const ForgotPasswordView = () => import("./views/ForgotPasswordView.vue");
const ResetPasswordView = () => import("./views/ResetPasswordView.vue");
const EmailRevertView = () => import("./views/EmailRevertView.vue");
const RegisterView = () => import("./views/RegisterView.vue");
const ProfileView = () => import("./views/ProfileView.vue");
const ForbiddenView = () => import("./views/ForbiddenView.vue");
const NotFoundView = () => import("./views/NotFoundView.vue");
const AppErrorView = () => import("./views/AppErrorView.vue");
const { loadUser, can } = useAuth();

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/login", component: LoginView, meta: { guestOnly: true } },
    { path: "/forgot-password", component: ForgotPasswordView, meta: { guestOnly: true } },
    { path: "/reset-password", component: ResetPasswordView, meta: { guestOnly: true } },
    { path: "/email-revert", component: EmailRevertView },
    { path: "/register", component: RegisterView, meta: { guestOnly: true } },
    { path: "/403", component: ForbiddenView },
    { path: "/error", component: AppErrorView },
    ...adminRouteRecords(),
    { path: "/admin/sessions", redirect: "/profile" },
    { path: "/account/security", redirect: "/profile" },
    { path: "/profile", component: ProfileView, meta: { permission: "profile.view", layout: "admin" } },
    { path: "/:pathMatch(.*)*", component: NotFoundView },
  ],
});

router.beforeEach(async (to) => {
  startNavigationLoading();
  if (to.meta.guestOnly) {
    const user = await loadUser();
    if (user) return authenticatedLandingPath(user.permissions);
    return true;
  }
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
