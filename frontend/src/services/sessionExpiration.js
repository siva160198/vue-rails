let authenticationRequiredHandler;

export function registerAuthenticationRequiredHandler(handler) {
  authenticationRequiredHandler = handler;
  return () => {
    if (authenticationRequiredHandler === handler) authenticationRequiredHandler = undefined;
  };
}

export function notifyAuthenticationRequired(error) {
  authenticationRequiredHandler?.(error);
}

export function resetAuthenticationRequiredHandler() {
  authenticationRequiredHandler = undefined;
}
