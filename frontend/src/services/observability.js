import * as Sentry from "@sentry/vue";

let initialized = false;

export function initObservability(app, router) {
  const dsn = import.meta.env.VITE_SENTRY_DSN;
  if (!dsn) return false;

  const tracesSampleRate = Number(import.meta.env.VITE_SENTRY_TRACES_SAMPLE_RATE || 0);
  Sentry.init({
    app,
    dsn,
    environment: import.meta.env.VITE_APP_ENV || import.meta.env.MODE,
    release: import.meta.env.VITE_APP_RELEASE || undefined,
    sendDefaultPii: false,
    attachErrorHandler: false,
    integrations: tracesSampleRate > 0
      ? [Sentry.browserTracingIntegration({ router })]
      : [],
    tracesSampleRate: Math.min(1, Math.max(0, tracesSampleRate)),
  });
  initialized = true;
  return true;
}

export function captureAppError(error) {
  if (!initialized) return;
  Sentry.captureException(error, {
    tags: error?.requestId ? { request_id: error.requestId } : undefined,
  });
}
