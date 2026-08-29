import { mount } from "@vue/test-utils";
import { describe, expect, it } from "vitest";
import TableActionButton from "./TableActionButton.vue";

describe("TableActionButton", () => {
  it("uses a specific accessible label and a responsive visible label", () => {
    const wrapper = mount(TableActionButton, {
      props: {
        action: "edit",
        label: "Edit",
        accessibleLabel: "Edit Support role",
      },
    });

    expect(wrapper.get("button").attributes("aria-label")).toBe(
      "Edit Support role",
    );
    expect(wrapper.get("span").classes()).toContain("xl:inline");
    expect(wrapper.text()).toContain("Edit");
  });

  it("blocks duplicate delete actions while loading", () => {
    const wrapper = mount(TableActionButton, {
      props: { action: "delete", label: "Delete", loading: true },
    });

    expect(wrapper.get("button").attributes("disabled")).toBeDefined();
    expect(wrapper.get("button").attributes("aria-busy")).toBe("true");
  });
});
