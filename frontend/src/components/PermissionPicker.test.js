import { mount } from "@vue/test-utils";
import { afterEach, describe, expect, it } from "vitest";
import PermissionPicker from "./PermissionPicker.vue";

const permissions = Array.from({ length: 6 }, (_, index) => ({
  key: `test.permission_${index + 1}`,
  name: `Permission ${index + 1}`,
  description: `Description ${index + 1}`,
}));

afterEach(() => {
  document.body.innerHTML = "";
});

describe("PermissionPicker", () => {
  it("keeps More available while readonly permissions remain locked", async () => {
    const wrapper = mount(PermissionPicker, {
      attachTo: document.body,
      props: {
        modelValue: permissions.map((permission) => permission.key),
        permissions,
        readonly: true,
      },
    });

    expect(wrapper.findAll('input[type="checkbox"]')).toHaveLength(5);
    expect(
      wrapper
        .findAll('input[type="checkbox"]')
        .every((input) => input.attributes("disabled") !== undefined),
    ).toBe(true);

    const moreButton = wrapper.find("button");
    expect(moreButton.attributes("disabled")).toBeUndefined();
    await moreButton.trigger("click");

    expect(document.body.querySelector('[role="dialog"]')).not.toBeNull();
    expect(
      [...document.body.querySelectorAll('[role="dialog"] input')].every(
        (input) => input.disabled,
      ),
    ).toBe(true);

    wrapper.unmount();
  });
});
