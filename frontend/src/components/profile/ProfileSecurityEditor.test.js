import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";
import ProfileSecurityEditor from "./ProfileSecurityEditor.vue";
import { apiFetch } from "../../services/api";
import { resetAuthState, useAuth } from "../../services/auth";
import AppModal from '../AppModal.vue';
import StepUpPrompt from '../security/StepUpPrompt.vue';
import { h } from 'vue';
import { confirmToast } from '../../services/toast';

vi.mock("../../services/api", () => ({ apiFetch: vi.fn() }));
vi.mock("../../services/passkeys", () => ({ passkeysSupported: () => true, registerPasskey: vi.fn() }));
vi.mock("../../services/toast", () => ({ toast: { success: vi.fn(), error: vi.fn(), info: vi.fn() }, confirmToast: vi.fn() }));

describe("ProfileSecurityEditor", () => {
  beforeEach(() => {
    apiFetch.mockReset();
    resetAuthState();
    useAuth().setUser({ email_address: "member@example.com" });
  });

  it("changes a valid password and emits saved", async () => {
    apiFetch
      .mockResolvedValueOnce({ challenge_token: "step-up", email_hint: "m***@example.com" })
      .mockResolvedValueOnce({ step_up_token: "grant" })
      .mockResolvedValueOnce({ user: { email_address: "member@example.com" } });
    const wrapper = mount(ProfileSecurityEditor, { props: { feature: "password" } });
    const inputs = wrapper.findAll("input");
    await inputs[0].setValue("old-password-value");
    await inputs[1].setValue("new-password-value");
    await inputs[2].setValue("new-password-value");
    await wrapper.get("form").trigger("submit");
    await flushPromises();
    const stepUpForm = wrapper.findAll("form")[1];
    await stepUpForm.trigger("submit");
    await flushPromises();
    await stepUpForm.get('input[name="code"]').setValue("123456");
    await stepUpForm.trigger("submit");
    await flushPromises();

    expect(apiFetch).toHaveBeenCalledWith("/api/v1/account_security/password", expect.objectContaining({ method: "PATCH" }));
    expect(wrapper.emitted("saved")).toHaveLength(1);
  });

  it("requests and verifies an email change", async () => {
    apiFetch.mockResolvedValueOnce({ challenge_token: "email-token", email_hint: "n***@example.com" }).mockResolvedValueOnce({ user: { email_address: "new@example.com" } });
    const wrapper = mount(ProfileSecurityEditor, { props: { feature: "email" } });
    await wrapper.findAll("input")[0].setValue("old-password-value");
    await wrapper.findAll("input")[1].setValue("new@example.com");
    await wrapper.get("form").trigger("submit");
    await flushPromises();
    await wrapper.get("input").setValue("123456");
    await wrapper.get("form").trigger("submit");
    await flushPromises();

    expect(apiFetch).toHaveBeenCalledTimes(2);
    expect(wrapper.emitted("saved")).toHaveLength(1);
  });

  it("requests and regenerates recovery codes", async () => {
    apiFetch.mockResolvedValueOnce({ challenge_token: "recovery-token", email_hint: "m***@example.com" }).mockResolvedValueOnce({ recovery_codes: ["code-one", "code-two"] });
    const wrapper = mount(ProfileSecurityEditor, { props: { feature: "recovery" } });
    await wrapper.get("input").setValue("old-password-value");
    await wrapper.get("form").trigger("submit");
    await flushPromises();
    await wrapper.get("input").setValue("123456");
    await wrapper.get("form").trigger("submit");
    await flushPromises();

    expect(wrapper.text()).toContain("code-one");
    expect(apiFetch).toHaveBeenCalledTimes(2);
  });

  it("loads passkey state only when its lazy editor opens", async () => {
    apiFetch.mockResolvedValueOnce({ passkeys: [], passkeys_enabled: false });
    const wrapper = mount(ProfileSecurityEditor, { props: { feature: "passkeys" } });
    await flushPromises();

    expect(apiFetch).toHaveBeenCalledWith("/api/v1/account_security?per_page=1");
    expect(wrapper.text()).toContain("Passkey belum dikonfigurasi");
  });

  it('allows cancelling pending passkey verification but blocks closing during actual deletion', async () => {
    let completeRemoval;
    apiFetch.mockResolvedValueOnce({ passkeys: [{ id: 1, nickname: 'Laptop' }], passkeys_enabled: true })
      .mockImplementationOnce(() => new Promise(resolve => { completeRemoval = resolve; }));
    confirmToast.mockResolvedValue(true);
    const wrapper = mount(AppModal, { attachTo: document.body, props: { open: true, title: 'Passkeys' }, slots: { default: () => h(ProfileSecurityEditor, { feature: 'passkeys' }) } });
    await flushPromises();
    await wrapper.findComponent(ProfileSecurityEditor).findComponent({ name: 'TableActionButton' }).trigger('click');
    await flushPromises();
    // Waiting for the user is not a network request; closing must not be deadlocked.
    wrapper.vm.requestClose();
    expect(wrapper.emitted('close')).toHaveLength(1);
    wrapper.findComponent(StepUpPrompt).vm.$emit('verified', 'grant');
    await flushPromises();
    wrapper.vm.requestClose();
    expect(wrapper.emitted('close')).toHaveLength(1);
    completeRemoval({});
    await flushPromises();
    wrapper.vm.requestClose();
    expect(wrapper.emitted('close')).toHaveLength(2);
    wrapper.unmount();
  });
});
