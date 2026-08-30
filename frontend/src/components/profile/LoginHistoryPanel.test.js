import { flushPromises, mount } from "@vue/test-utils";
import { describe, expect, it, vi } from "vitest";
import LoginHistoryPanel from "./LoginHistoryPanel.vue";
import { apiFetch } from "../../services/api";

vi.mock("../../services/api", () => ({ apiFetch: vi.fn() }));

describe("LoginHistoryPanel", () => {
  it("loads login history only after the panel is mounted", async () => {
    apiFetch.mockResolvedValueOnce({ events: [{ id: 1, action: "session.created", ip_address: "127.0.0.1", user_agent: "Browser", created_at: "2026-08-29T00:00:00Z" }], pagination: { total: 1 } });
    const wrapper = mount(LoginHistoryPanel);
    await new Promise((resolve) => setTimeout(resolve, 10));
    await flushPromises();

    expect(apiFetch).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain("session.created");
    expect(wrapper.text()).toContain("Browser");
  });
});
