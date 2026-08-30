import { mount } from "@vue/test-utils";
import { nextTick } from "vue";
import { describe, expect, it } from "vitest";
import LanguageSwitcher from "./LanguageSwitcher.vue";

describe("LanguageSwitcher", () => {
  it("closes the language menu when clicking outside", async () => {
    const wrapper = mount(LanguageSwitcher);
    await wrapper.get("button").trigger("click");
    expect(wrapper.text()).toContain("Indonesia");

    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    await nextTick();
    expect(wrapper.text()).not.toContain("Indonesia");
  });
});
