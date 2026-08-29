import { mount } from "@vue/test-utils";
import axe from "axe-core";
import { afterEach, describe, expect, it } from "vitest";
import { dismissToast, toast, toasts } from "../services/toast";
import ToastContainer from "./ToastContainer.vue";

afterEach(() => {
  for (const item of [...toasts.value]) dismissToast(item.id, false);
});

describe("ToastContainer", () => {
  it("announces feedback and has no detectable axe violations", async () => {
    const wrapper = mount(ToastContainer, { attachTo: document.body });
    toast.error("Request failed", { duration: 0 });
    await wrapper.vm.$nextTick();

    expect(document.body.querySelector('[role="alert"]')).not.toBeNull();
    const result = await axe.run(document.body, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(result.violations).toEqual([]);
    wrapper.unmount();
  });
});
