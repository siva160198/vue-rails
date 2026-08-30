import { mount } from "@vue/test-utils";
import axe from "axe-core";
import { describe, expect, it } from "vitest";
import FormField from "./FormField.vue";
import TextInput from "./TextInput.vue";

describe("FormField", () => {
  it("associates labels, help, and server errors with its control", async () => {
    const wrapper = mount(FormField, {
      attachTo: document.body,
      props: { label: "Email", help: "Use work email", error: ["is invalid"] },
      slots: { default: TextInput },
    });

    const input = wrapper.get("input");
    expect(wrapper.get("label").attributes("for")).toBe(input.attributes("id"));
    expect(input.attributes("aria-invalid")).toBe("true");
    expect(input.attributes("aria-describedby").split(" ")).toHaveLength(2);
    const result = await axe.run(wrapper.element, {
      rules: { "color-contrast": { enabled: false } },
    });
    expect(result.violations).toEqual([]);
    wrapper.unmount();
  });

  it("does not mark a field invalid for an empty error array", () => {
    const wrapper = mount(FormField, {
      props: { label: "Email", error: [] },
      slots: { default: TextInput },
    });

    expect(wrapper.get("input").attributes("aria-invalid")).toBe("false");
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
  });
});
