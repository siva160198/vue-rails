import { beforeEach, describe, expect, it, vi } from "vitest";

const sentry = vi.hoisted(() => ({
  init: vi.fn(),
  captureException: vi.fn(),
  browserTracingIntegration: vi.fn(() => "tracing"),
}));
vi.mock("@sentry/vue", () => sentry);

describe("observability", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    vi.unstubAllEnvs();
  });

  it("stays disabled without a DSN", async () => {
    const { initObservability, captureAppError } = await import("./observability");

    expect(initObservability({}, {})).toBe(false);
    captureAppError(new Error("ignored"));
    expect(sentry.init).not.toHaveBeenCalled();
    expect(sentry.captureException).not.toHaveBeenCalled();
  });

  it("initializes Sentry and attaches a request id to captured errors", async () => {
    vi.stubEnv("VITE_SENTRY_DSN", "https://public@example.test/1");
    vi.stubEnv("VITE_SENTRY_TRACES_SAMPLE_RATE", "0.25");
    const { initObservability, captureAppError } = await import("./observability");
    const error = Object.assign(new Error("failed"), { requestId: "request-123" });

    expect(initObservability({}, {})).toBe(true);
    captureAppError(error);

    expect(sentry.init).toHaveBeenCalledWith(expect.objectContaining({
      dsn: "https://public@example.test/1",
      tracesSampleRate: 0.25,
      sendDefaultPii: false,
    }));
    expect(sentry.captureException).toHaveBeenCalledWith(error, {
      tags: { request_id: "request-123" },
    });
  });
});
