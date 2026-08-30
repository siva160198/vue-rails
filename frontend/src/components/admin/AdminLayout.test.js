import { mount } from "@vue/test-utils";
import { nextTick } from "vue";
import { beforeEach, describe, expect, it, vi } from "vitest";
import AdminLayout from "./AdminLayout.vue";
import { resetAuthState, useAuth } from "../../services/auth";

vi.mock("vue-router", () => ({
  useRoute: () => ({ path: "/admin" }),
  useRouter: () => ({ push: vi.fn() }),
}));

beforeEach(() => {
  resetAuthState();
  useAuth().setUser({
    email_address: "admin@example.com",
    permissions: ["dashboard.view", "profile.view"],
  });
});

function mountLayout() {
  return mount(AdminLayout, {
    global: {
      stubs: {
        RouterLink: { template: "<a><slot /></a>" },
      },
    },
  });
}

describe("AdminLayout", () => {
  it("collapses the desktop sidebar to an icon rail and persists the choice", async () => {
    const wrapper = mountLayout();

    await wrapper.get('[aria-label="Kecilkan sidebar"]').trigger("click");

    expect(wrapper.get("aside").classes()).toContain("lg:w-[90px]");
    expect(wrapper.get('[aria-label="Lebarkan sidebar"]').exists()).toBe(true);
    expect(localStorage.getItem("vue_rails-sidebar")).toBe("closed");
  });

  it("restores the collapsed sidebar preference", async () => {
    localStorage.setItem("vue_rails-sidebar", "closed");
    const wrapper = mountLayout();
    await nextTick();

    expect(wrapper.get("aside").classes()).toContain("lg:w-[90px]");
  });

  it("shows the profile link above sign out in the account dropdown", async () => {
    const wrapper = mountLayout();
    await wrapper.get('[aria-label="Menu akun"]').trigger("click");

    const dropdownText = wrapper.text();
    expect(dropdownText.indexOf("Profil")).toBeGreaterThan(-1);
    expect(dropdownText.indexOf("Profil")).toBeLessThan(dropdownText.indexOf("Keluar"));

    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    await nextTick();
    expect(wrapper.text()).not.toContain("Keluar");
  });

  it("closes the notification dropdown when clicking outside", async () => {
    const wrapper = mountLayout();
    await wrapper.get('[aria-label="Notifikasi"]').trigger("click");
    expect(wrapper.text()).toContain("Belum ada notifikasi baru.");

    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    await nextTick();
    expect(wrapper.text()).not.toContain("Belum ada notifikasi baru.");
  });

  it("shows only a visually truncated name before the account menu opens", () => {
    useAuth().setUser({ first_name: "Alexander", last_name: "Hamilton", email_address: "alex@example.com", permissions: ["dashboard.view", "profile.view"] });
    const wrapper = mountLayout();
    const label = wrapper.get('[aria-label="Menu akun"] strong');

    expect(label.text()).toBe("Alexander Hamilton");
    expect(label.classes()).toContain("max-w-[8ch]");
    expect(wrapper.get('[aria-label="Menu akun"]').text()).not.toContain("alex@example.com");
  });
});
