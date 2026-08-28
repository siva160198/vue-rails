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
- Authorization policies are under `app/policies`.
- Authentication helpers are in `app/controllers/concerns/authentication.rb`.
- Vue application code is under `frontend/src`.
- Frontend API requests go through `frontend/src/services/api.js`.
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
  until data changes. Create/submit buttons remain disabled until required input is valid.
  Rails update endpoints must short-circuit no-op writes and must not create audit logs for them.
- Keep the frontend palette limited to brand blue, neutral gray, and error red.
  Form controls must inherit the shared Tailwind styling in `frontend/src/style.css`;
  do not introduce browser-default checkboxes/selects or new accent color families.
- Vue routes are defined in `frontend/src/router.js`.
- The admin shell is `frontend/src/components/admin/AdminLayout.vue`.
- Rails routes are defined in `config/routes.rb`.
- PostgreSQL configuration is in `config/database.yml`.

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
- Keep Rails controllers JSON-only under `/api/v1`.
- Return JSON errors for API authentication and authorization failures.
- Use Rails' native authentication flow; do not introduce Devise.
- Add a Pundit policy for protected resources and call `authorize` in controllers.
- Keep credentials and generated admin passwords out of Git.
- Put reusable starter functionality here; business-specific code belongs in a
  project created from this template.
- Preserve existing user changes and avoid unrelated rewrites.

## UI and UX Standards

- TailAdmin is the authoritative design system for every visual asset, page, layout,
  component, form, table, modal, dropdown, navigation element, icon treatment, loading
  state, and interaction pattern. Follow the existing TailAdmin template and its reusable
  components exactly; do not invent an independent design or visual pattern.
- Before creating or changing UI, inspect the relevant existing TailAdmin component or
  pattern in this repository and reuse it. If no relevant TailAdmin reference exists,
  ask the user for direction before designing a new pattern.
- Whenever a change would introduce or materially change a modal, tell the user before
  implementing it. Briefly explain the modal's purpose, the TailAdmin modal pattern being
  followed, its backdrop/interaction behavior, and whether opening or using it makes any
  server request. Do not silently introduce a modal.
- Use Tailwind CSS utilities and the existing TailAdmin admin shell. Reuse shared
  TailAdmin-based components before introducing any page-specific variant.
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
- While a DataTable request is active, show its built-in TailAdmin spinner overlay,
  set `aria-busy`, dim the table, and block table controls until loading finishes.
- DataTable API endpoints must use server-side pagination and allow at most 50 rows per
  request. Load only the active page, debounce remote search, whitelist sortable columns,
  and never fetch an entire unbounded table up front. Route lazy loading must ensure
  tables on unopened pages make no request.
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
- User verification status uses check/X icons. User active status uses a toggle switch.
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

## Verification

- Run focused Rails tests while developing, then `bin/rails test` before handoff.
- For frontend changes, run `npm run build --prefix frontend`.
- Run `npm test --prefix frontend` for Vue unit/component changes.
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
