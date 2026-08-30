# Vue Rails Starter

Reusable full-stack starter for applications that need a Rails JSON API,
Vue frontend, PostgreSQL, authentication, authorization, and an admin panel.

## Included stack

- Vue 3, Vite, Vue Router
- Tailwind CSS 4
- TailAdmin-style responsive admin dashboard
- Ruby on Rails 8 JSON/REST API
- PostgreSQL
- Rails native session authentication with CSRF protection
- Email OTP two-factor authentication through Action Mailer
- Public member registration with email verification
- Pundit authorization with `admin` and `member` roles
- Admin user management and security audit log
- CORS configuration and Vite development proxy
- Minitest, Vitest, and Playwright E2E coverage
- Multi-stage production Docker image for Rails and Vue

## Create a project

Use GitHub's **Use this template** button, or clone the repository:

```sh
git clone https://github.com/siva160198/vue-rails.git my_project
cd my_project
bin/bootstrap my_project
```

`bin/bootstrap` will:

1. Rename the Rails application and database configuration.
2. Install Ruby and frontend dependencies.
3. Create and prepare the PostgreSQL development/test databases.
4. Generate a random development admin password.
5. Start Rails on port 3000 and Vite on port 5173.

Use snake_case for the project name. To prepare without starting servers:

```sh
bin/bootstrap my_project --skip-server
```

## Requirements

- Ruby 4.0.6 through rbenv
- Node.js 20.19 or newer; Node 22 recommended
- PostgreSQL 17 or compatible

On macOS with Homebrew:

```sh
brew install rbenv postgresql@17
brew services start postgresql@17
```

Install the Ruby version if it is not available:

```sh
rbenv install 4.0.6
```

## Daily development

After the first bootstrap, run both applications with:

```sh
bin/dev
```

- Frontend: http://localhost:5173
- Rails API: http://localhost:3000/api/v1/status
- Admin login: http://localhost:5173/login

For dependency and database maintenance without renaming the application:

```sh
bin/setup --skip-server
```

## Development admin

The bootstrap command prints a randomly generated admin password. It is never
stored in Git. To create or promote a known development administrator later:

```sh
ADMIN_EMAIL=admin@example.test ADMIN_PASSWORD='your-secure-password' bin/rails db:seed
```

The seed only creates this account in the development environment.

## Email OTP

Login requires a six-digit email OTP after the password is accepted. In
development, outgoing messages can be opened at
`http://localhost:3000/letter_opener` without an email provider. This inbox is
only mounted in development. The OTP expires after five minutes, is single-use,
and is locked after five failed attempts.

OTP and password-reset messages are enqueued on Solid Queue's dedicated
`mailers` queue. Production must run a separate worker with `bin/jobs`; temporary
SMTP failures are retried with backoff up to four attempts. The test environment
uses the inline adapter so controller tests can inspect generated messages.

For production, configure an SMTP provider with:

```sh
MAILER_FROM=no-reply@example.com
SUPPORT_EMAIL=example@mail.com
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
SMTP_AUTHENTICATION=plain
SMTP_STARTTLS_AUTO=true
```

Store these values in the deployment platform's secret manager, never in Git.
`SUPPORT_EMAIL` is shown to users whose account has been disabled.

## Member registration

Public registration is available at `http://localhost:5173/register`. New
accounts always receive the `member` role, require a password of at least 12
characters, and must verify their email with OTP before a session is created.

## Languages

The starter uses Rails' built-in I18n and a dependency-free Vue translation
service. Indonesian is the default and English is selectable from the header.
Vue sends the saved locale to Rails through `Accept-Language`, so localized API
responses and the interface use the same language.
Administrator accounts are created or promoted separately through trusted
server-side operations such as the development seed.

## Password recovery

The login page links to `http://localhost:5173/forgot-password`. Password
recovery emails a Rails-signed reset link that expires after fifteen minutes and
becomes invalid as soon as the password changes. The frontend verifies the token
before showing the new-password form. A successful reset revokes all existing
sessions for the account. Development reset emails appear in
`http://localhost:3000/letter_opener`.

## Production configuration

Copy `.env.example` into the deployment platform's secret/configuration system.
Production enables HTTPS/HSTS, secure cookies, CSP, security headers, and SMTP
validation by default. Set `FRONTEND_ORIGIN` only when Vue is deployed on a
different origin; the Docker image serves Vue and Rails from one origin.

Production boot fails early when required configuration is missing, insecure, or
still contains template placeholder values. Replace every example value in
`.env.example`, especially `APP_HOST`, `FRONTEND_URL`, `DATABASE_URL`, mail
addresses, and SMTP configuration.

Build the image, run the release migration once, then start separate web and job
processes from the same image:

```sh
docker build -t my_project \
  --build-arg VITE_SENTRY_DSN="$VITE_SENTRY_DSN" \
  --build-arg VITE_APP_RELEASE="$APP_RELEASE" .
docker run --rm --env-file .env my_project bin/release
docker run --env-file .env -p 80:80 --name my_project-web my_project
docker run --env-file .env --name my_project-jobs my_project bin/jobs
```

Do not run migrations independently in every web replica. `bin/release` must
complete before new containers receive traffic. Roll application code back by
redeploying the previous image; database rollback is always reviewed and explicit.

The Docker build uses Ruby 4.0.6 and Node 22, builds Vue into
`public/frontend`, and serves SPA routes through Rails. Never commit `.env`,
`config/master.key`, or deployed application credentials.

### Health checks

- `GET /up` is the dependency-free liveness probe used by Docker.
- `GET /api/v1/readiness` verifies mandatory dependencies but exposes only a generic
  ready/unavailable result. In production it requires the secret `X-Readiness-Token`,
  is rate-limited, and briefly caches probes; detailed component health remains internal.
  Set `MAX_REQUEST_BODY`, `HTTP_READ_TIMEOUT`, `RACK_TIMEOUT_SERVICE_TIMEOUT`,
  `DATABASE_STATEMENT_TIMEOUT_MS`, and `DATABASE_LOCK_TIMEOUT_MS` using the safe defaults
  in `.env.example` so slow or oversized work is bounded at both Thruster and Rails.
  Load balancers should only send traffic after it returns `200`.

### Observability

Production Rails logs are JSON with timestamp, severity, message, and request ID.
Vue generates `X-Request-ID` for every API request; Rails returns it and API errors
retain it for diagnostics.

Sentry is optional and disabled when its DSN is blank. Configure `SENTRY_DSN` for
Rails and inject `VITE_SENTRY_DSN` when building Vue. Trace sampling defaults to
zero and default PII collection stays disabled. Set `APP_RELEASE` and
`VITE_APP_RELEASE` to the same immutable image or Git revision.

Kamal defines separate web and job roles. Run `bin/kamal release` once during the
release phase before switching traffic.

## Admin operations

- User management: `http://localhost:5173/admin/users`
- Audit logs: `http://localhost:5173/admin/audit-logs`
- Active devices: `http://localhost:5173/admin/sessions`
- Account security: `http://localhost:5173/account/security`
- Profile: `http://localhost:5173/profile`

Admins can search users, change member/admin roles, and disable accounts. An
admin cannot change their own access. Disabling a user revokes their sessions,
and security-sensitive actions are written to the audit log.

Users can review their own active login sessions, see login time, IP address, and
browser user-agent, revoke one session, or revoke every session except the current
device. Every successful login sends a security notification email. Session APIs
are always ownership-scoped and never expose another user's devices.

The TailAdmin account menu in the top-right header shows the user's truncated name and
links to Profile directly above Sign out. Profile is one account hub without tabs: personal
information, account-security actions, active devices, and login history use lazy Edit/View
modals. Profile photos are changed from stable actions in the Personal Information modal and stored as stripped, square
AVIF files no larger than 50 KB; SVG uploads are rejected.

The Account security page supports changing the current password after a single-use
password-plus-OTP/TOTP step-up, changing email
after verification at the new address, personal login history, and recovery-code
regeneration protected by both the current password and an email OTP. Passkeys are
optional: set `WEBAUTHN_RP_ID` and `WEBAUTHN_ORIGIN` together (plus the optional
`WEBAUTHN_RP_NAME`) to enable registration and sign-in. Production origins must use
HTTPS; password and email OTP remain available as fallback authentication methods.
RFC 6238 authenticator apps are supported without an external service. TOTP secrets and
profile phone numbers are encrypted at rest. Roles listed in `MFA_REQUIRED_ROLES` cannot
remove their final enrolled TOTP/passkey method.

Sessions have both an idle timeout (`SESSION_IDLE_TIMEOUT_MINUTES`) and an absolute
lifetime (`SESSION_ABSOLUTE_LIFETIME_DAYS`). Security credential changes rotate the
current session, revoke other sessions, and invalidate trusted-browser grants. Login
protection applies per-account lockout plus combined IP/account-digest detection to
slow credential stuffing without storing attempted email addresses. Administrators
must complete MFA on every new login when included in `MFA_REQUIRED_ROLES` (the default is
`admin`). Sensitive actions use the reusable `/api/v1/step_up` flow and consume a
database-backed, short-lived, purpose-bound grant exactly once. Password history rejects
the five latest passwords; `PASSWORD_BREACH_CHECK_ENABLED=true` additionally enables the
privacy-preserving HIBP range lookup.

Old-address email notifications contain a 24-hour signed reversal link. Reversal restores
the previous address and revokes every session. Password, passkey, and authenticator changes
also send a "not me" security notification. Optional upload malware scanning uses ClamAV
when `MALWARE_SCAN_ENABLED=true`; uploads fail closed if the configured scanner is unavailable.
Set `ADMIN_DUAL_CONTROL_ENABLED=true` to require a second administrator to approve exact
role, permission, and account-access payloads. Pending requests appear under Security
approvals, cannot be self-approved, expire after 30 minutes, and are consumed once.

When an authenticated Vue request receives `401 AUTHENTICATION_REQUIRED`, the global
session-expiration coordinator clears the singleton auth state, invalidates the cached
CSRF token, shows one localized toast, and redirects to login while preserving the full
current URL in the `redirect` query. Concurrent failures are deduplicated and ordinary
invalid-login responses never trigger this behavior.

Adaptive login protection uses a bounded progressive delay and a risk score based on
recent IP failures, distinct account digests, account history, and whether the browser
has an existing session history. A hard account lock is reserved for repeated high-risk
failures; a successfully verified CAPTCHA can still authenticate and clear an abusive
lock, reducing email-targeted denial of service. Suspicious-login email is limited to
one notification per hour per account and links to password recovery.

Cloudflare Turnstile is optional. Set `TURNSTILE_SITE_KEY` and
`TURNSTILE_SECRET_KEY` together to enable its inline SPA widget and mandatory server-side
Siteverify validation. Tokens are never logged or persisted. `TRUSTED_LOGIN_NETWORKS`
accepts comma-separated CIDRs and is matched only against Rails `request.remote_ip`;
configure trusted reverse proxies at the infrastructure layer before relying on it.

## API documentation

Large collections (`users`, `audit_logs`, account login history, and failed jobs) use
opaque signed cursor pagination. Follow `next_cursor` or `previous_cursor` from the
response; a cursor is valid only for the same search, sort, and direction. Exact totals
are intentionally omitted from normal requests. API consumers may send
`include_total=true` when a briefly cached exact count is genuinely needed.

The formal OpenAPI 3.1 contract is [docs/openapi.yml](docs/openapi.yml). It
documents authentication cookies, CSRF headers, request/response schemas,
pagination, errors, account sessions, and admin endpoints. The Rails contract test
fails when a concrete `/api/v1` route is added or removed without updating OpenAPI,
when operation IDs collide, or when a mutation omits its CSRF requirement.

## Verification

```sh
bin/rails test
npm test --prefix frontend
npm run test:coverage --prefix frontend
npm run test:e2e --prefix frontend
npm run build --prefix frontend
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit check
npm audit --prefix frontend --audit-level=high
```

Rails tests generate a SimpleCov report in `tmp/coverage`. Frontend coverage is
generated in `tmp/frontend-coverage`. CI enforces the configured coverage floors and
uploads both HTML reports as build artifacts.

Playwright starts Rails and Vite automatically. Install its Chromium runtime
once on a development machine with:

```sh
npx --prefix frontend playwright install chromium
```

## Template maintenance

Keep this repository generic. Add reusable infrastructure and UI components
here, but add business-specific models, migrations, and credentials only after
creating a project from the template.
Authenticated administrators with `api_docs.view` can open the interactive Swagger UI at
`/admin/api-docs`. The source contract remains `docs/openapi.yml`.

## Operations

Backup, restore, deployment, rollback, monitoring, and incident procedures are documented in
[`docs/operations.md`](docs/operations.md). `bin/backup` and `bin/restore` require PostgreSQL's
client tools. Solid Queue failures can be inspected and managed at `/admin/jobs`.

Use `bin/generate_admin_resource plural_resource` before adding a business resource. It validates
the name and prints the complete integration checklist without guessing fields or overwriting the
route, permission, OpenAPI, and translation registries.
