import { flushPromises, mount } from "@vue/test-utils";
import { afterEach, describe, expect, it, vi } from "vitest";
import TurnstileInput from "./TurnstileInput.vue";

describe("TurnstileInput", () => {
  afterEach(() => { delete window.turnstile; });

  it("renders explicitly, emits the token, and exposes reset", async () => {
    let configuration;
    window.turnstile = {
      render: vi.fn((_element, options) => { configuration = options; return "widget-1"; }),
      reset: vi.fn(),
      remove: vi.fn(),
    };
    const wrapper = mount(TurnstileInput, { props: { siteKey: "site-key" } });
    await flushPromises();

    expect(window.turnstile.render).toHaveBeenCalled();
    configuration.callback("verified-token");
    expect(wrapper.emitted("verified")[0]).toEqual(["verified-token"]);
    wrapper.vm.reset();
    expect(window.turnstile.reset).toHaveBeenCalledWith("widget-1");
  });
});
