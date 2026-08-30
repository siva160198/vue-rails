import { describe, expect, it } from "vitest";
import { useFormErrors } from "./formErrors";

describe("useFormErrors", () => {
  it("maps API details, focuses the first invalid field, and clears per field", async () => {
    const form = document.createElement("form");
    const email = document.createElement("input");
    email.name = "email_address";
    form.append(email);
    document.body.append(form);
    const { errorFor, clearError, applyApiError } = useFormErrors();

    const handled = await applyApiError(
      { details: { email_address: ["has already been taken"] } },
      form,
    );

    expect(handled).toBe(true);
    expect(errorFor("email_address")).toEqual(["has already been taken"]);
    expect(document.activeElement).toBe(email);
    clearError("email_address");
    expect(errorFor("email_address")).toEqual([]);
  });

  it("uses a fallback field for API errors without details", async () => {
    const form = document.createElement("form");
    const password = document.createElement("input");
    password.name = "password";
    form.append(password);
    document.body.append(form);
    const { errorFor, applyApiError } = useFormErrors();

    expect(await applyApiError({ message: "Invalid credentials", details: {} }, form, "password")).toBe(true);
    expect(errorFor("password")).toEqual(["Invalid credentials"]);
    expect(document.activeElement).toBe(password);
  });

  it("blocks invalid client data and focuses its first field", async () => {
    const form = document.createElement("form");
    const email = document.createElement("input");
    email.name = "email_address";
    form.append(email);
    document.body.append(form);
    const { errorFor, validate } = useFormErrors();

    expect(await validate({ email_address: "Enter a valid email" }, form)).toBe(false);
    expect(errorFor("email_address")).toEqual(["Enter a valid email"]);
    expect(document.activeElement).toBe(email);
  });
});
