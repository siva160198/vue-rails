import { apiFetch } from "./api";

export function passkeysSupported() {
  return Boolean(
    window.PublicKeyCredential?.parseCreationOptionsFromJSON &&
      window.PublicKeyCredential?.parseRequestOptionsFromJSON,
  );
}

export async function registerPasskey({ nickname, currentPassword }) {
  const payload = await apiFetch("/api/v1/passkeys/options", {
    method: "POST",
    body: JSON.stringify({ current_password: currentPassword }),
  });
  const credential = await navigator.credentials.create({
    publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(payload.options),
  });
  if (!credential) throw new Error("PASSKEY_CANCELLED");
  return apiFetch("/api/v1/passkeys", {
    method: "POST",
    body: JSON.stringify({ nickname, challenge_token: payload.challenge_token, credential: credential.toJSON() }),
  });
}

export async function authenticateWithPasskey(emailAddress) {
  const payload = await apiFetch("/api/v1/session/passkey_options", {
    method: "POST",
    body: JSON.stringify({ email_address: emailAddress }),
  });
  const credential = await navigator.credentials.get({
    publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(payload.options),
  });
  if (!credential) throw new Error("PASSKEY_CANCELLED");
  return apiFetch("/api/v1/session/passkey", {
    method: "POST",
    body: JSON.stringify({ challenge_token: payload.challenge_token, credential: credential.toJSON() }),
  });
}
