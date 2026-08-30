import { flushPromises, mount } from "@vue/test-utils";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ProfileView from "./ProfileView.vue";
import { resetAuthState, useAuth } from "../services/auth";
import { apiFetch } from "../services/api";

vi.mock("../services/api", () => ({ apiFetch: vi.fn() }));
vi.mock("vue-router", () => ({
  useRoute: () => ({ query: {} }),
  useRouter: () => ({ replace: vi.fn() }),
}));

const profile = {
  id: 1,
  email_address: "member@example.com",
  role: "member",
  email_verified_at: "2026-08-29T00:00:00Z",
  first_name: "Siva",
  last_name: "Kumar",
  phone: "+62 812",
  created_at: "2026-08-01T00:00:00Z",
  avatar_url: null,
};

function mountView() {
  return mount(ProfileView, {
    global: {
      stubs: {
        AdminLayout: { template: "<main><slot /></main>" },
        RouterLink: { props: ["to"], template: '<a :href="to"><slot /></a>' },
      },
    },
  });
}

describe("ProfileView", () => {
  beforeEach(() => {
    resetAuthState();
    useAuth().setUser({
      ...profile,
      permissions: ["profile.view", "profile.update", "account_security.view", "account_security.update", "sessions.view"],
    });
    apiFetch.mockReset();
  });

  afterEach(() => { document.body.innerHTML = ""; });

  it("loads account security and active-device summaries on the profile page", async () => {
    apiFetch.mockResolvedValueOnce({ profile });
    const wrapper = mountView();

    expect(wrapper.get('[role="status"]').exists()).toBe(true);
    await flushPromises();

    expect(apiFetch).toHaveBeenCalledWith("/api/v1/profile");
    expect(wrapper.text()).toContain("member@example.com");
    expect(wrapper.text()).toContain("Keamanan akun");
    expect(wrapper.text()).toContain("Perangkat aktif");
  });

  it("changes the profile photo directly from the avatar without a separate upload form", async () => {
    apiFetch.mockResolvedValueOnce({ profile });
    const wrapper = mountView();
    await flushPromises();

    await wrapper.findAll("button").find((button) => button.text().includes("Edit")).trigger("click");
    expect(document.body.querySelector('input[type="file"]').getAttribute("accept")).toContain("image/avif");
    expect(document.body.textContent).toContain("Ganti foto profil");
    expect(wrapper.text()).not.toContain("Pilih gambar");
  });

  it("uses one page and opens personal information in an edit modal", async () => {
    apiFetch.mockResolvedValueOnce({ profile });
    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find("nav").exists()).toBe(false);
    await wrapper.findAll("button").find((button) => button.text().includes("Edit")).trigger("click");

    expect(document.body.querySelector('[role="dialog"]')).not.toBeNull();
    expect(document.body.querySelector('[autocomplete="given-name"]').value).toBe("Siva");
    expect(document.body.querySelector('[autocomplete="family-name"]').value).toBe("Kumar");
  });
});
