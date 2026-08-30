# Project Guide

This repository is a reusable full-stack starter. Read this file and inspect only
the files relevant to the requested change; do not scan the entire repository by
default.

## Stack

- Backend: Ruby 4.0.6, Rails 8.1 JSON/REST API
- Frontend: Vue 3, Vite, Vue Router, Tailwind CSS 4
- Database: PostgreSQL
- Authentication: Rails native session authentication using signed HTTP-only cookies
  plus email OTP challenges through Action Mailer
- Authorization: Pundit with database-backed roles and granular permissions
- Notifications: global floating Vue toasts through `frontend/src/services/toast.js`
- Localization: Rails I18n plus the dependency-free Vue translator in
  `frontend/src/services/i18n.js`; default Indonesian with English available
- Tests: Rails Minitest, Vitest, and Playwright

## Architecture

- Rails API code is under `app/controllers/api/v1`.
- Admin API endpoints are under `app/controllers/api/v1/admin`.
- Admin user management and audit logs are exposed under `/api/v1/admin` and
  protected by `UserPolicy` and `AuditLogPolicy`.
- Public member registration is handled by `Api::V1::RegistrationsController`.
- Password recovery is handled by `Api::V1::PasswordResetsController` and uses
  Rails' native `password_reset_token`; it must never create an authenticated session.
- Authentication and recovery email must use `deliver_later` through
  `MailDeliveryJob` on the `mailers` queue. Production runs `bin/jobs` separately;
  never reintroduce request-blocking `deliver_now`. Retry only transient delivery
  failures with bounded attempts and cover queue behavior with tests.
- Authorization policies are under `app/policies`.
- Authentication helpers are in `app/controllers/concerns/authentication.rb`.
- Vue application code is under `frontend/src`.
- Frontend API requests go through `frontend/src/services/api.js`.
- Global session-expiry handling is registered once from `main.js` through
  `sessionExpirationCoordinator.js`. Only a `401` carrying the stable
  `AUTHENTICATION_REQUIRED` code may clear shared auth state, show the localized expiry
  toast, and redirect to `/login` with the complete current `fullPath` in `redirect`.
  Never treat login `INVALID_CREDENTIALS` or another arbitrary `401` as an expired
  session. Deduplicate concurrent expiry responses and reset the cached CSRF token.
- Every frontend API request carries a generated `X-Request-ID`. Preserve and expose
  it through proxies/CORS, attach the response ID to API errors, and include it in
  monitoring context. Never log passwords, email, OTP, reset tokens, cookies, or bodies.
- Frontend authentication state must go through the singleton `useAuth()` composable in
  `frontend/src/services/auth.js`. Do not call `currentUser()` independently from routes,
  layouts, or pages, duplicate logout handlers, or inspect permission arrays directly.
  Use `loadUser`, `setUser`, `logout`, `can`, and `canAny`; successful login/verification
  must update the shared user and logout must clear it. Keep concurrent session requests
  deduplicated and cache both authenticated and anonymous results.
- Server-backed Vue tables must use `useServerTable()` from
  `frontend/src/services/serverTable.js` for items, loading, query serialization,
  standardized pagination state, response hooks, row replacement/removal, error toasts,
  and stale-response protection. Do not duplicate table request/loading/total logic in
  page components. Business-specific payload transformations remain at the call site.
- Every new user-facing feature must ship Indonesian and English translations together.
  Vue strings must use `t()` from `frontend/src/services/i18n.js`, and Rails responses
  must use matching locale keys under both `config/locales/id.yml` and `en.yml`;
  do not hardcode new UI messages.
- User-facing success, error, warning, and info notifications must use the global
  toast API from `frontend/src/services/toast.js`; do not add page-local alert boxes.
- Every button that starts an asynchronous operation must use
  `frontend/src/components/AsyncButton.vue`, expose a contextual loading label,
  and remain disabled until the operation finishes. Use per-row loading state for tables.
- Edit actions must track their original snapshot and keep save buttons disabled
  until data changes. Invalid create/submit actions must run client validation and explain
  every problem inline instead of remaining silently disabled; only no-change and in-flight
  actions stay disabled.
  Rails update endpoints must short-circuit no-op writes and must not create audit logs for them.
- Keep the frontend palette limited to brand blue, neutral gray, and error red.
  Form controls must inherit the shared Tailwind styling in `frontend/src/style.css`;
  do not introduce browser-default checkboxes/selects or new accent color families.
- Vue routes are defined in `frontend/src/router.js`.
- The admin shell is `frontend/src/components/admin/AdminLayout.vue`.
- Header dropdowns (language, notifications, and account) must be mutually lightweight
  and close on outside click through the shared `useClickOutside` composable.
- The TailAdmin account dropdown must show the lazy `/profile` link immediately above
  Sign out and render the current avatar when available. Profile photo upload/removal
  belongs only on the Profile page, never on Active Devices. Profile is a single TailAdmin-style
  page without tabs or separate self-service sidebar entries. Editable sections use an Edit
  button and a lazy TailAdmin modal; table/history sections use View and fetch only when opened.
  Password, email, recovery-code, and passkey forms each use their own security modal. Avatar
  selection and stable Change/Remove actions live inside the Personal Information Edit modal;
  never depend on hover-only avatar actions. The server must autorotate, strip metadata,
  center-crop, resize, and encode a real AVIF of at most 50 KB (never accept SVG). Profile access requires
  `profile.view`, mutations require `profile.update`, and both remain ownership-scoped.
- Rails routes are defined in `config/routes.rb`.
- `docs/openapi.yml` is the authoritative public API contract. Every endpoint change
  must update paths, operation IDs, security, parameters, request/response schemas,
  status codes, and shared components in the same change. Contract tests must keep
  concrete `/api/v1` routes, CSRF requirements, pagination, and error schemas aligned.
- PostgreSQL configuration is in `config/database.yml`.
- Operational backup/restore commands are `bin/backup` and `bin/restore`; the reviewed
  production procedures are authoritative in `docs/operations.md`.

## Development Commands

```sh
bin/dev
bin/rails test
npm test --prefix frontend
npm run test:e2e --prefix frontend
npm run build --prefix frontend
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit check --update
npm audit --prefix frontend
```

For first-time setup of a project created from this template:

```sh
bin/bootstrap project_name
```

Use a snake_case project name. `bin/bootstrap` renames the application, installs
dependencies, prepares PostgreSQL, creates a development admin, and starts the
Rails and Vite development servers. Use `--skip-server` when appropriate.

## Implementation Conventions

- Never run `git push` unless the user explicitly asks to push in the current request.
  Completing a code change does not imply permission to push. Leave changes in the
  working tree unless the user also explicitly requests a commit.
- Production exception monitoring is optional and configured only through Sentry
  environment variables. Keep Rails/Vue releases aligned, default PII disabled, and
  trace sampling explicit and conservative. The app must work with monitoring disabled;
  production Rails logs remain structured JSON with request ID.
- Keep `/up` as a dependency-free liveness probe and `/api/v1/readiness` as the
  dependency probe for PostgreSQL and Solid Queue storage. Add every new mandatory
  runtime dependency to readiness with success/failure tests without exposing internals.
- Production boot validates required environment variables and rejects placeholder or
  insecure values, except during `SECRET_KEY_BASE_DUMMY` image compilation. Update
  `.env.example`, validation, rename/bootstrap behavior, and docs together for new vars.
- Never run `db:prepare` from every web entrypoint. Run `bin/release` exactly once before
  switching traffic, then start web and `bin/jobs` as separate processes from the same
  immutable image. Database rollback is always explicit and reviewed.
- Keep Rails controllers JSON-only under `/api/v1`.
- Return JSON errors for API authentication and authorization failures.
- Every failed API response must use the shared `render_api_error` contract:
  `{ error: { code, message, details } }`. Codes are stable uppercase identifiers,
  messages come from matching `api.errors` keys in both Rails locales, and `details` is
  always an object (field validation errors belong there). Never render a bare error
  string, leak exception text, or make frontend behavior depend on translated messages.
- Use `render_validation_error(record)` for Active Model validation failures. Add a new
  bilingual locale entry and tests whenever a new API error code is introduced. The Vue
  API client must expose HTTP `status`, API `code`, `message`, and `details`, while keeping
  temporary compatibility with legacy string errors during migrations.
- Treat the API error contract as mandatory for every new or changed endpoint and every
  failure status, including malformed requests (400), unauthenticated access (401),
  forbidden actions (403), missing routes/records (404), validation and CSRF failures
  (422), rate limits (429), and unexpected server errors (500). API failures must never
  fall through to an HTML error page or produce a JSON shape unique to one controller.
- Before handing off API work, search for bare `render json: { error: ... }` responses and
  replace them with the shared helpers. Tests must assert the HTTP status, stable error
  code, translated message where relevant, and that `details` is always an object. Add
  frontend client coverage whenever parsing or consuming the error payload changes.
- Choose error codes by meaning rather than UI wording, keep them uppercase snake case,
  and do not rename an existing code casually because clients may depend on it. Business
  logic uses `error.code`; user feedback uses the localized `error.message`; field forms
  use `error.details`. Never branch application behavior by matching message text.
- Use Rails' native authentication flow; do not introduce Devise.
- Add a Pundit policy for protected resources and call `authorize` in controllers.
- Every new protected page or resource must add database-backed permissions in the same
  change. Use `resource.view` for page/list/detail access and add only the mutation keys
  actually supported by the feature: `resource.create`, `resource.update`, and
  `resource.delete`. Use a specific verb such as `orders.approve`, `users.export`, or
  `reports.download` for sensitive actions that do not fit CRUD.
- Permission work is incomplete unless it includes an idempotent production migration,
  updated seeds, automatic assignment to the administrator role, dependency rules (for
  example, update implies view), Indonesian and English names/descriptions, Pundit policy
  checks, controller `authorize` calls, Vue route/menu/action visibility, and tests for
  both allowed and forbidden access. Never rely on frontend hiding as authorization.
- Do not create permissions for purely presentational controls such as filters,
  pagination, tabs, modal open/close, or ordinary form fields. Require a separate
  permission for server-side mutations, destructive operations, sensitive data access,
  exports/downloads, approvals, impersonation, or other privileged business actions.
- Keep credentials and generated admin passwords out of Git.
- Treat backup as incomplete until restore is tested against an isolated database. Keep
  dumps outside the release, mode `0600`, encrypted off-site, and governed by explicit
  retention. Never restore over production without `RESTORE_CONFIRM`, a fresh backup,
  and an approved incident plan.
- Retain sessions, login challenges, audit logs, finished queue jobs, and unattached
  uploads through scheduled bounded jobs. Retention durations come from environment
  variables and destructive cleanup must be idempotent and covered by tests.
- Every mandatory runtime datastore must have a readiness check. Queue monitoring uses
  Solid Queue's separate database in every environment; never query private queue tables
  from the Vue client or expose job arguments/backtraces, which may contain sensitive data.
- Failed-job retry/discard requires `jobs.update`, must create an audit log, and must use
  per-row loading plus confirmation toast. Queue listing requires `jobs.view`, reusable
  server pagination, bounded search, and lazy route loading.
- Active Storage is the native upload system. Validate MIME type and byte size on the
  model/server, use multipart `FormData` without forcing a JSON Content-Type, authorize
  ownership, audit mutations, and support local plus environment-configured S3-compatible
  storage. Never trust the browser filename or MIME declaration alone.
- New authentication sessions must enforce `MAX_ACTIVE_SESSIONS`, store IP/user-agent,
  notify the account by email, and be user-revocable. Record successful, failed, revoked,
  and password-change events without storing plaintext credentials, OTP/token values, or
  raw attempted email addresses. Password changes revoke all sessions and send a security
  notification asynchronously.
- Every session must enforce configurable idle and absolute expiry on the server, touch
  activity at a bounded frequency, expose last activity/expiry in device management,
  and rotate after password or email changes. Credential changes must also invalidate
  trusted-browser and outstanding step-up grants through `authentication_version`.
- Login protection must combine generic per-account temporary lockout with bounded
  IP-plus-email-digest credential-stuffing detection. Never store raw attempted emails,
  never reveal account existence through early failure responses, and audit blocked
  attempts without credentials. Retain login-attempt records only for the bounded
  operational window.
- Adaptive lockout must resist account-targeted denial of service: use a bounded
  progressive delay, combine account state with IP/distinct-digest/device familiarity,
  and reserve hard lock for repeated high-risk failures. A valid optional CAPTCHA must
  permit correct credentials to recover from an abusive lock. Suspicious-login email
  is queued with a per-account cooldown and never includes secrets or raw attempted
  emails. Trusted login networks come only from validated server-side CIDRs matched
  against Rails `request.remote_ip`; never trust a client-supplied forwarding header.
- Optional CAPTCHA uses Cloudflare Turnstile explicit rendering for the Vue SPA and
  server-side Siteverify on every submitted token. Site and secret keys must be configured
  together, the secret stays server-only, validation fails closed, tokens are treated as
  single-use/short-lived, and the widget resets after any attempted submission. The
  login form remains fully functional without CAPTCHA configuration.
- Sensitive features should compose `StepUpAuthentication`: current-password challenge,
  email OTP, single-use challenge, and a short-lived signed purpose-bound grant tied to
  the user's `authentication_version`. Never accept a grant for another user or purpose.
  When `ADMIN_MFA_REQUIRED=true`, administrators cannot use trusted-browser OTP bypass;
  password plus OTP or a verified passkey is required for every new admin session.
- Step-up grants are database-backed, purpose-bound, authentication-version-bound, and
  single-use. Password changes, TOTP removal, passkey deletion, mass session revocation,
  admin user access changes, and role/permission mutations must consume the matching
  grant. Validate ownership, authorization, and field validity before asking for step-up
  so invalid or forbidden requests never create misleading verification prompts.
- When `ADMIN_DUAL_CONTROL_ENABLED=true`, user access and role/permission changes use
  `AdminDualControl`: store only a canonical payload summary/digest, require approval by a
  different active administrator, expire requests after 30 minutes, and consume approval
  for the exact requester/action/payload. The requester must still complete a fresh
  purpose-bound step-up when retrying the approved mutation. Approval pages require
  `security_approvals.view/update` and must never allow self-approval.
- Account MFA supports email OTP, recovery codes, WebAuthn, and RFC 6238 TOTP. Store TOTP
  secrets encrypted at rest, never return them after enrollment, require a verified code
  before activation, and prevent roles listed in `MFA_REQUIRED_ROLES` from removing their
  final enrolled MFA method. Authenticator codes may satisfy an email step-up challenge.
- Password mutations require at least 12 characters, reject the current password and five
  recent password digests, optionally use the HIBP k-anonymity range API, revoke sessions,
  rotate authentication trust, and queue a "not me" security notification. Never send a
  full password or password hash to an external breach service.
- Email changes verify the new address and notify the old address with a signed, expiring,
  single-use reversal link. Reversal restores the old address, increments
  `authentication_version`, and revokes every session. Passkey additions/removals and TOTP
  changes also queue security notifications.
- Encrypt private profile fields such as phone numbers at rest with `SecurityEncryptor`.
  Preserve legacy plaintext reads during migrations, never expose ciphertext through API
  serializers, and allocate database columns for ciphertext expansion.
- `AuditLog` is append-only through Active Record, HMAC-chained, and emits a minimal
  structured `security_audit` event suitable for an external immutable log sink. Never log
  credentials or security tokens. Retention deletion may use bounded SQL cleanup, and chain
  backfills must accompany digest format changes.
- Uploads are quarantined in request temp storage until decoding, dimension checks,
  metadata stripping, conversion, and optional fail-closed ClamAV scanning complete.
  Keep malware scanning disabled unless its scanner is installed and production-validated.
- Production responses keep HSTS, CSP reporting, COOP, CORP, referrer, permissions, and
  nosniff headers enabled. CSP browser reports are the only mutation exempt from CSRF because
  the browser sends them outside the application fetch flow; sanitize their logged fields.
- CI security gates include Brakeman, Bundler Audit, npm audit, secret scanning, CodeQL,
  a HIGH/CRITICAL container scan, CycloneDX SBOM generation, OWASP ZAP OpenAPI scanning,
  and an isolated backup restore. Pin every third-party GitHub Action to a reviewed commit
  SHA and let Dependabot propose controlled updates for Actions, Bundler, and npm.
- Swagger UI is an admin-only lazy-loaded viewer for the committed `docs/openapi.yml`;
  access requires `api_docs.view`. It never replaces contract tests or permits production
  credentials to be persisted in browser storage.
- `bin/generate_admin_resource` validates plural snake_case resource names and is the
  starting checklist for new admin resources. Generated work is not complete until route,
  Pundit policy, permissions/migration/seeds/fixtures, server pagination, OpenAPI, bilingual
  UI, lazy route/menu, TailAdmin DataTable/form/modal patterns, audit, and tests are present.
- E2E coverage must include the happy authentication path, forbidden member access, core
  admin pages, session management, role/permission disclosure, job monitoring, API docs,
  and at least desktop plus iPad/mobile navigation behavior. Do not make E2E depend on
  production services; use isolated test databases and local mail delivery.
- Put reusable starter functionality here; business-specific code belongs in a
  project created from this template.
- Preserve existing user changes and avoid unrelated rewrites.
- Never leave framework/template placeholder branding in user-facing metadata or assets,
  including `frontend`, `Vite`, default favicons, generic document titles, descriptions,
  application names, and theme colors. `frontend/index.html` must identify the current
  application, use the default Indonesian document language, and follow the TailAdmin
  brand palette. `bin/rename_app` must update document metadata for generated projects.

## UI and UX Standards

- TailAdmin is the authoritative design system for every visual asset, page, layout,
  component, form, table, modal, dropdown, navigation element, icon treatment, loading
  state, and interaction pattern. Follow the existing TailAdmin template and its reusable
  components exactly; do not invent an independent design or visual pattern.
- This TailAdmin-first rule applies without exception to both public and admin UI,
  including authentication and error pages, buttons, inputs, textareas, selects,
  checkboxes, toggles, cards, badges, tabs, breadcrumbs, pagination, toasts, dialogs,
  empty states, skeletons, spinners, tooltips, popovers, headers, sidebars, and responsive
  behavior. TailAdmin is the first reference for every element and UX decision.
- Do not introduce a UI library, component style, or interaction convention from another
  template when TailAdmin already provides an equivalent. A third-party component may be
  used only when explicitly approved by the user and must be visually adapted to the
  existing TailAdmin system.
- Before creating or changing UI, inspect the relevant existing TailAdmin component or
  pattern in this repository and reuse it. If no relevant TailAdmin reference exists,
  ask the user for direction before designing a new pattern.
- Whenever a change would introduce or materially change a modal, tell the user before
  implementing it. Briefly explain the modal's purpose, the TailAdmin modal pattern being
  followed, its backdrop/interaction behavior, and whether opening or using it makes any
  server request. Do not silently introduce a modal.
- Use Tailwind CSS utilities and the existing TailAdmin admin shell. Reuse shared
  TailAdmin-based components before introducing any page-specific variant.
- Every modal must use the shared TailAdmin `frontend/src/components/AppModal.vue`;
  do not duplicate Teleport, backdrop, header, close, scroll-lock, Escape, or footer
  markup in page components. Nested modals must use the shared modal stack so Escape
  closes only the top modal, and modal behavior requires component regression tests.
- A modal that edits server-backed resource data must open immediately, lazy-load the
  current detail through a dedicated authorized `show` endpoint, and display AppModal's
  blocking spinner until the request completes. Disable closing and interaction while
  loading, protect against stale responses, show API failures through toast, and never
  preload every row's edit payload. Purely local disclosure modals such as a permission
  “More” picker reuse AppModal but must not make a redundant server request.
- Standard forms must compose `FormField.vue` with `TextInput.vue`,
  `TextareaInput.vue`, `ToggleInput.vue`, and `SelectInput.vue`; do not duplicate labels,
  help/error text, or raw page-specific control styles. Raw inputs are limited to
  specialized reusable internals such as DataTable search and permission checkboxes.
- Forms that call the API must use `useFormErrors()` to map the standardized
  `error.details` payload to matching field names, clear a field's error when it changes,
  supplement field feedback with a global summary toast, and focus the first invalid control.
  Toast alone is never sufficient for a field-specific error. Every Rails
  validation field returned to Vue must match the form control's `name`. FormField and
  its shared controls must preserve label, help, error, `aria-describedby`, and
  `aria-invalid` associations; do not implement page-local validation-error markup.
- Keep colors restrained to brand blue, neutral gray, and error red. Do not add new
  decorative color families or gradients without an explicit product requirement.
- Use the shared form-control rules in `frontend/src/style.css` for every input,
  textarea, select, checkbox, and toggle. Controls must support focus, disabled, and
  dark states and must not fall back to browser-default styling.
- Every select control must use the TailAdmin-style
  `frontend/src/components/SelectInput.vue` with native Vue `v-model` and the shared flat
  Lucide chevron. Do not use raw `<select>`, Select2, jQuery, emoji arrows, or custom
  page-specific select styling.
- Every tabular data view must use the shared TailAdmin-style
  `frontend/src/components/DataTable.vue`; do not add plain tables. DataTable views must
  provide search, sortable columns, page-size selection, pagination, result counts,
  loading state, empty state, responsive overflow, and both `id`/`en` translations.
- Keep resource tables read-only and concise. Do not place editable inputs, selects,
  textareas, permission grids, or active controls directly in rows. Use AppModal for
  multi-field editing and follow the server-backed modal lazy-loading rule above. Submit
  to the server only when the user has made an actual change.
- Table actions must use consistent Lucide icons: Pencil for edit, Save for save, and
  Trash2 for delete. On desktop widths of 1280px and above, show icon plus translated
  label; below 1280px (including iPad and mobile), show an icon-only square control with
  localized `aria-label` and `title`. Loading replaces the action icon with a spinner.
- Render edit/save/delete actions through the reusable TailAdmin
  `frontend/src/components/TableActionButton.vue`; do not recreate responsive action
  sizing, colors, icons, loading, disabled state, labels, or accessibility per table.
- Clamp long table descriptions to two lines and expose the complete value through a
  title or TailAdmin tooltip. Put related counts or statuses in their own compact columns
  instead of mixing controls and secondary content into description cells.
- Treat read-only and disabled states as different UX states. Read-only content cannot
  be changed, but disclosure controls such as More, View details, accordions, tabs, and
  modal open/close controls must remain usable. Never disable a parent component merely
  to lock its editable fields; test that users can still inspect all hidden content.
- AppModal must trap keyboard focus inside the top-most dialog, support Escape, focus an
  appropriate control when opened, and restore focus to its opener when closed. New or
  materially changed shared UI must include axe-core regression coverage plus explicit
  keyboard/focus assertions where jsdom can verify behavior. Never treat automated axe
  checks as a replacement for semantic labels, visible focus, or responsive manual QA.
- While a DataTable request is active, show its built-in TailAdmin spinner overlay,
  set `aria-busy`, dim the table, and block table controls until loading finishes.
- DataTable API endpoints must use server-side pagination and allow at most 50 rows per
  request. Load only the active page, debounce remote search, whitelist sortable columns,
  and never fetch an entire unbounded table up front. Route lazy loading must ensure
  tables on unopened pages make no request.
- Every paginated Rails endpoint must use the shared `ApiPagination#paginate_api` concern;
  do not duplicate page, per-page, search, sort, direction, offset, or metadata logic in
  controllers. Declare explicit search and sortable-column whitelists at each call site.
- Paginated responses always return `pagination: { page, per_page, total, total_pages }`.
  The concern clamps page values, enforces 5–50 rows per request, limits search input,
  escapes SQL wildcard characters, rejects non-whitelisted sorting through a safe
  fallback, and adds deterministic ordering. Add regression tests for metadata, maximum
  page size, invalid parameters, search behavior, and authorization for new resources.
- Use `frontend/src/components/AsyncButton.vue` for every asynchronous action. Show a
  spinner and contextual loading text, disable the button while processing, and prevent
  duplicate submissions.
- Disable save/update buttons when the form has no changes. Track original snapshots,
  avoid no-op API requests, and make Rails update endpoints short-circuit no-op writes.
- Use global floating toasts for all user feedback. Do not add inline alert boxes.
  Toasts auto-dismiss, include progress, support confirmation actions, and place the
  close control at the top-left without overlapping content.
- Every route is lazy-loaded. Route and language changes use the full-screen navigation
  loading overlay, which blocks interaction and shows a spinner for at least 250 ms.
- Use `frontend/src/components/LanguageSwitcher.vue` everywhere a language control is
  needed. It uses flat SVG flags, not emoji, and its 40x40 circular trigger matches the
  notification and theme buttons. In the admin header it belongs beside notifications.
- The desktop sidebar collapses to an icon rail; it must never disappear completely.
  User and role pages stay grouped under the expandable User Management tree.
- Use Lucide icons consistently. Prefer simple flat icons and avoid ornamental,
  AI-styled, emoji, or mismatched icon treatments.
- User verification status uses check/X icons. In read-only tables, user active status
  uses a TailAdmin status badge; the active-status edit control uses a toggle switch only
  inside the edit modal.
- Keep 403, 404, and application-error pages available and bilingual.

## Localization Standards

- Indonesian (`id`) is the default language and English (`en`) is mandatory. Every new
  user-facing string must be added in both languages in the same change.
- Vue strings use `t()` from `frontend/src/services/i18n.js`; never hardcode labels,
  placeholders, accessibility text, toast messages, loading text, or error-page copy.
- Rails user-facing responses and mail copy use Rails I18n with matching keys in
  `config/locales/id.yml` and `config/locales/en.yml`.
- Vue persists the locale in `localStorage`, updates the document `lang`, and sends it
  to Rails through `Accept-Language`. Language switching must not make an extra API call.

## Authentication UX

- The public header contains Home, Admin, and the language switcher; do not add a
  registration link there. Registration remains reachable from the login page.
- Opening an admin route while signed out redirects to login, preserves the requested
  destination, and shows a localized toast explaining that login is required.
- Login first accepts email/password and then shows a separate verification step when
  OTP is required. Do not label the login action as sending an OTP.
- If an existing account is unverified, show a localized toast, issue a new challenge,
  and take the user directly to verification without creating a duplicate user.
- A successful OTP verification trusts that browser for one hour using the signed,
  expiring `otp_trust` cookie. Login during that window must not send another OTP.
- Inactive users with a correct password receive a localized toast directing them to
  `SUPPORT_EMAIL`; wrong credentials must not reveal account status.
- Password recovery is email-link based. The signed reset token must be validated before
  accepting a new password, and a successful reset revokes all existing sessions.
- Active-device management is always scoped to `Current.user.sessions` through
  `SessionPolicy`; never find a revocable session globally. Listing requires
  `sessions.view`, revocation requires `sessions.delete`, the current session is visibly
  marked, and security actions create audit logs. Every successful new session queues a
  bilingual login-notification email containing time, IP, and user-agent but no secrets.
- Account-security mutations require `account_security.update` and remain ownership
  scoped. Changing a password requires the current password, rejects no-op reuse,
  revokes other sessions, audits the event, and queues a security email. Changing email
  requires the current password plus an OTP sent to the new address, marks it verified
  only after OTP success, revokes other sessions, and notifies the previous address.
  Recovery-code regeneration requires current-password confirmation followed by a
  separate email OTP and shows generated codes only once.
- WebAuthn/passkeys are optional and use the maintained `webauthn` gem plus browser-native
  WebAuthn JSON methods; never implement cryptography manually. Enable only when both
  `WEBAUTHN_RP_ID` and `WEBAUTHN_ORIGIN` are set, require user verification, persist and
  update signature counters, use short-lived signed ceremony challenges, and preserve
  password/email-OTP fallback. Account security is an inline TailAdmin page, not a modal.

## Verification

- Run focused Rails tests while developing, then `bin/rails test` before handoff.
- For frontend changes, run `npm run build --prefix frontend`.
- Run `npm test --prefix frontend` for Vue unit/component changes.
- Run `npm run test:coverage --prefix frontend` before handoff when reusable frontend
  code changes. CI enforces the committed Vitest line/function/branch/statement floors
  and uploads the HTML report; do not lower a threshold merely to make a change pass.
- Rails tests always produce SimpleCov output under `tmp/coverage`; CI enforces line and
  branch floors. New backend branches and new reusable frontend states require tests so
  coverage does not regress. Coverage artifacts must remain untracked.
- Run Playwright E2E for authentication or cross-stack flow changes when a browser is available.
- For Ruby changes, run `bin/rubocop`.
- For security-sensitive or dependency changes, also run the security audit
  commands listed above.
- Report any checks that could not be run and why.

## Important Behavior

- Authentication uses a signed `session_id` cookie and CSRF protection.
- A session is created after password authentication and successful email OTP verification;
  the verified browser may skip OTP for one hour.
- Public registration can only create `member` users; never permit a client-supplied role.
- Successful password resets must revoke all existing sessions for the user.
- Disabling a user revokes their sessions; admins cannot update their own access.
- Security-sensitive authentication and admin changes are written to `AuditLog`.
- Vite proxies API traffic to Rails during development.
- Development emails are available at `/letter_opener`; this route must remain development-only.
- Development admin credentials are generated by `bin/bootstrap` and printed
  once; no default password is committed.
- `bin/rename_app` updates application identifiers and the frontend package name.
