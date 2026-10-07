import { mount } from "@vue/test-utils";
import { afterEach, describe, expect, it } from "vitest";
import axe from "axe-core";
import AppModal from "./AppModal.vue";
import { defineComponent, h, ref } from 'vue';
import { useModalGuard } from '../composables/useModalGuard';

afterEach(() => {
  document.body.innerHTML = "";
  globalThis.__vue_railsModalStack = [];
});

describe("AppModal", () => {
  it('keeps a dirty draft on cancel and confirms discard on backdrop, Escape and footer', async () => {
    const wrapper = mount(AppModal, { attachTo: document.body, props: { open: true, title: 'Edit', dirty: true }, slots: { default: '<input aria-label="Draft" value="Unsaved">', footer: ({ requestClose }) => h('button', { onClick: requestClose }, 'Cancel edit') } });
    await wrapper.vm.$nextTick();
    document.querySelector('footer button').click();
    await wrapper.vm.$nextTick();
    expect(document.querySelectorAll('[role="dialog"]')).toHaveLength(2);
    expect(document.querySelector('[role="dialog"]').parentElement.hasAttribute('inert')).toBe(true);
    expect((await axe.run(document.body, { rules: { 'color-contrast': { enabled: false } } })).violations).toEqual([]);
    expect(wrapper.emitted('close')).toBeUndefined();
    let dialogs = document.querySelectorAll('[role="dialog"]');
    dialogs[1].querySelector('footer button').click();
    await wrapper.vm.$nextTick();
    expect(document.querySelector('input').value).toBe('Unsaved');
    expect(document.querySelector('[role="dialog"]').contains(document.activeElement)).toBe(true);
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await wrapper.vm.$nextTick();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await wrapper.vm.$nextTick();
    expect(wrapper.emitted('close')).toBeUndefined();
    document.querySelector('[role="dialog"]').parentElement.click();
    await wrapper.vm.$nextTick();
    dialogs = document.querySelectorAll('[role="dialog"]');
    dialogs[1].querySelectorAll('footer button')[1].click();
    await wrapper.vm.$nextTick();
    expect(wrapper.emitted('close')).toHaveLength(1);
    await wrapper.setProps({ open: false });
    expect(document.querySelectorAll('[role="dialog"]')).toHaveLength(0);
    wrapper.unmount();
  });

  it('registers nested reactive form dirty/busy state and removes it on unmount', async () => {
    const dirty = ref(true), busy = ref(false), visible = ref(true);
    const Form = defineComponent({ setup() { useModalGuard(() => ({ dirty: dirty.value, busy: busy.value })); return () => h('input', { 'aria-label': 'Draft' }); } });
    const wrapper = mount(AppModal, { attachTo: document.body, props: { open: true, title: 'Edit' }, slots: { default: () => visible.value ? h(Form) : null } });
    await wrapper.vm.$nextTick();
    busy.value = true;
    await wrapper.vm.$nextTick();
    wrapper.vm.requestClose();
    expect(wrapper.emitted('close')).toBeUndefined();
    expect(document.querySelectorAll('[role="dialog"]')).toHaveLength(1);
    busy.value = false;
    await wrapper.vm.$nextTick();
    wrapper.vm.requestClose();
    await wrapper.vm.$nextTick();
    expect(document.querySelectorAll('[role="dialog"]')).toHaveLength(2);
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await wrapper.vm.$nextTick();
    visible.value = false;
    await wrapper.vm.$nextTick();
    wrapper.vm.requestClose();
    expect(wrapper.emitted('close')).toHaveLength(1);
    wrapper.unmount();
  });

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
