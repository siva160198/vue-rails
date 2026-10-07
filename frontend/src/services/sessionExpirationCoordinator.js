import { registerAuthenticationRequiredHandler } from "./sessionExpiration";
import { lockSession, lockedAccount } from "./sessionLock";

export function installSessionExpirationHandler({ router, auth, notify, translate, schedule = window.setTimeout }) {
  let handling = false;

  return registerAuthenticationRequiredHandler(async () => {
    if (!auth.user.value || handling || lockedAccount.value) return;

    handling = true;
    if (auth.user.value.unlock_token) {
      lockSession(auth.user.value);
      notify(translate("auth.session_locked"));
      handling = false;
      return;
    }
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
