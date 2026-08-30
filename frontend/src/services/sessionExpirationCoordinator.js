import { registerAuthenticationRequiredHandler } from "./sessionExpiration";

export function installSessionExpirationHandler({ router, auth, notify, translate, schedule = window.setTimeout }) {
  let handling = false;

  return registerAuthenticationRequiredHandler(async () => {
    if (!auth.user.value || handling) return;

    handling = true;
    const currentRoute = router.currentRoute.value;
    const redirect = currentRoute.path === "/login" ? undefined : currentRoute.fullPath;
    auth.clearUser();
    notify(translate("auth.session_expired"));
    try {
      await router.replace({ path: "/login", query: redirect ? { redirect } : {} });
    } catch (error) {
      console.error("Session expiration redirect failed:", error);
    } finally {
      schedule(() => { handling = false; }, 0);
    }
  });
}
