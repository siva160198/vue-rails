import { mount } from "@vue/test-utils";
import axe from "axe-core";
import { describe, expect, it, vi } from "vitest";
import FileInput from "./FileInput.vue";
import FormField from "./FormField.vue";

describe("FileInput", () => {
  it("inherits accessible field metadata and emits change", async () => {
    const onChange = vi.fn();
    const wrapper = mount(FormField, {
      attachTo: document.body,
      props: { label: "Avatar", help: "PNG only" },
      slots: { default: { template: "<FileInput accept='image/png' @change='onChange' />", components: { FileInput }, setup: () => ({ onChange }) } },
    });
    const input = wrapper.get("input[type=file]");
    await input.trigger("change");

    expect(wrapper.get("label").attributes("for")).toBe(input.attributes("id"));
    expect(onChange).toHaveBeenCalledOnce();
    const result = await axe.run(wrapper.element, { rules: { "color-contrast": { enabled: false } } });
    expect(result.violations).toEqual([]);
    wrapper.unmount();
  });
});
