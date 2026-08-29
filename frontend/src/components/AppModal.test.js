import { mount } from "@vue/test-utils";
import { afterEach, describe, expect, it } from "vitest";
import axe from "axe-core";
import AppModal from "./AppModal.vue";

afterEach(() => {
  document.body.innerHTML = "";
  globalThis.__vue_railsModalStack = [];
});

describe("AppModal", () => {
  it("shows a blocking spinner while lazy data is loading", () => {
    const wrapper = mount(AppModal, {
      attachTo: document.body,
      props: { open: true, title: "Edit user", loading: true },
      slots: { default: "Loaded form", footer: "Actions" },
    });

    const dialog = document.body.querySelector('[role="dialog"]');
    expect(dialog?.getAttribute("aria-busy")).toBe("true");
    expect(document.body.querySelector('[role="status"]')).not.toBeNull();
    expect(document.body.textContent).not.toContain("Loaded form");
    expect(document.body.textContent).not.toContain("Actions");
    expect(document.body.querySelector("button")?.disabled).toBe(true);
    wrapper.unmount();
  });

  it("only lets the top nested modal handle Escape", async () => {
    const parent = mount(AppModal, {
      attachTo: document.body,
      props: { open: true, title: "Parent" },
    });
    const child = mount(AppModal, {
      attachTo: document.body,
      props: { open: true, title: "Child" },
    });

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(child.emitted("close")).toHaveLength(1);
    expect(parent.emitted("close")).toBeUndefined();
    child.unmount();
    parent.unmount();
  });

  it("traps focus, restores the opener, and has no detectable axe violations", async () => {
    const opener = document.createElement("button");
    opener.textContent = "Open";
    document.body.append(opener);
    opener.focus();
    const wrapper = mount(AppModal, {
      attachTo: document.body,
      props: { open: true, title: "Edit role" },
      slots: {
        default: '<input aria-label="Role name"><button>Save</button>',
      },
    });
    await wrapper.vm.$nextTick();

    const result = await axe.run(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(result.violations).toEqual([]);

    const dialog = document.body.querySelector('[role="dialog"]');
    const focusable = dialog.querySelectorAll("button:not([disabled])");
    focusable[focusable.length - 1].focus();
    document.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Tab", bubbles: true, cancelable: true }),
    );
    expect(document.activeElement).toBe(focusable[0]);

    await wrapper.setProps({ open: false });
    expect(document.activeElement).toBe(opener);
    wrapper.unmount();
  });
});
