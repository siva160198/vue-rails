import { beforeEach, describe, expect, it, vi } from "vitest";
import { authenticateWithPasskey, passkeysSupported, registerPasskey } from "./passkeys";

vi.mock("./api", () => ({ apiFetch: vi.fn() }));
import { apiFetch } from "./api";

describe("passkeys", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.PublicKeyCredential = {
      parseCreationOptionsFromJSON: vi.fn((value) => value),
      parseRequestOptionsFromJSON: vi.fn((value) => value),
    };
  });

  it("detects native JSON support and completes registration", async () => {
    expect(passkeysSupported()).toBe(true);
    apiFetch.mockResolvedValueOnce({ options: { challenge: "x" }, challenge_token: "signed" }).mockResolvedValueOnce({ passkey: { id: 1 } });
    navigator.credentials = { create: vi.fn().mockResolvedValue({ toJSON: () => ({ id: "credential" }) }) };

    await expect(registerPasskey({ nickname: "Laptop", currentPassword: "secret" })).resolves.toEqual({ passkey: { id: 1 } });
    expect(apiFetch).toHaveBeenLastCalledWith("/api/v1/passkeys", expect.objectContaining({ method: "POST" }));
  });

  it("completes passkey authentication", async () => {
    apiFetch.mockResolvedValueOnce({ options: { challenge: "x" }, challenge_token: "signed" }).mockResolvedValueOnce({ user: { id: 1 } });
    navigator.credentials = { get: vi.fn().mockResolvedValue({ toJSON: () => ({ id: "credential" }) }) };

    await expect(authenticateWithPasskey("user@example.com")).resolves.toEqual({ user: { id: 1 } });
  });
});
