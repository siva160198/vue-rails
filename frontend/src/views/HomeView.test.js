import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";
import HomeView from "./HomeView.vue";
import { apiFetch } from "../services/api";

vi.mock("../services/api", () => ({ apiFetch: vi.fn() }));
vi.mock("../services/toast", () => ({
  toast: { error: vi.fn() },
}));

describe("HomeView", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders a healthy status response without database details", async () => {
    apiFetch.mockResolvedValue({ status: "ok" });

    const wrapper = mount(HomeView);
    await flushPromises();

    expect(wrapper.text()).toContain("API terhubung");
    expect(wrapper.text()).not.toContain("undefined");
  });
});
