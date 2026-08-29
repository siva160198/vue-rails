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
});
