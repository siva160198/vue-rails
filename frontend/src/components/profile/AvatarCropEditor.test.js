import { flushPromises, mount } from "@vue/test-utils";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import AvatarCropEditor from "./AvatarCropEditor.vue";

describe("AvatarCropEditor", () => {
  let originalImage;

  beforeEach(() => {
    originalImage = globalThis.Image;
    globalThis.URL.createObjectURL = vi.fn(() => "blob:avatar");
    globalThis.URL.revokeObjectURL = vi.fn();
    globalThis.Image = class {
      naturalWidth = 1200;
      naturalHeight = 800;
      set src(_value) { queueMicrotask(() => this.onload?.()); }
    };
    HTMLCanvasElement.prototype.getContext = vi.fn(() => ({
      clearRect: vi.fn(), fillRect: vi.fn(), save: vi.fn(), translate: vi.fn(),
      rotate: vi.fn(), drawImage: vi.fn(), restore: vi.fn(), fillStyle: "",
    }));
    HTMLCanvasElement.prototype.toBlob = vi.fn((callback) => callback(new Blob(["photo"], { type: "image/jpeg" })));
  });

  afterEach(() => { globalThis.Image = originalImage; });

  it("lets the user position, rotate, reset, and confirm a square avatar", async () => {
    const file = new File(["source"], "portrait.avif", { type: "image/avif" });
    const wrapper = mount(AvatarCropEditor, { props: { file } });
    await flushPromises();

    expect(wrapper.get("canvas").attributes("width")).toBe("640");
    expect(wrapper.get('input[type="range"]').attributes("max")).toBe("3");

    const buttons = wrapper.findAll("button");
    await buttons.find((button) => button.text().includes("Putar kanan")).trigger("click");
    await buttons.find((button) => button.text().includes("Atur ulang")).trigger("click");
    await buttons.find((button) => button.text().includes("Terapkan dan unggah")).trigger("click");

    const uploaded = wrapper.emitted("confirm")[0][0];
    expect(uploaded).toBeInstanceOf(File);
    expect(uploaded.type).toBe("image/jpeg");
    expect(URL.revokeObjectURL).not.toHaveBeenCalled();
    wrapper.unmount();
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:avatar");
  });
});
