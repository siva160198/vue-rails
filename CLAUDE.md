# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **reusable starter template**, not a product. Two apps live side by side:

- Rails 8.1 JSON API at the repo root (serves only `/api/v1/*`)
- Vue 3 + Vite SPA in [frontend/](frontend/)

`README.md` states the maintenance rule: keep this repository generic. Reusable infrastructure and UI belong here; business models, migrations, and credentials belong in projects created *from* the template.

### "Tourplan" is a placeholder, not the app name

The app currently identifies as `Tourplan` / `tourplan` / `TOURPLAN` (Rails module, DB names, Kamal service, UI strings). [bin/rename_app](bin/rename_app) rewrites those three exact casings across `Dockerfile README.md app config db frontend/src frontend/package.json`, and [bin/bootstrap](bin/bootstrap) decides whether renaming already happened by grepping `config/application.rb` for `module Tourplan`.

Consequences when editing template code:
- Any new project-identity string must use one of those three casings verbatim, or renaming will miss it.
- Adding a file outside the `paths` list in `bin/rename_app` means it will never be renamed.
- Don't hand-edit `module Tourplan` or the `tourplan_*` database names — that silently disables the bootstrap rename guard.

## Commands

```sh
bin/dev                        # Rails :3000 + Vite :5173 (spawns both, traps INT/TERM)
bin/setup --skip-server        # install gems + npm, db:prepare, clear logs/tmp
bin/rails test                 # Minitest (parallel, fixtures :all)
bin/rails test test/controllers/api/v1/sessions_controller_test.rb        # one file
bin/rails test test/controllers/api/v1/sessions_controller_test.rb:12     # one test by line
bin/rubocop                    # rubocop-rails-omakase
bin/ci                         # full local pipeline, see config/ci.rb
npm run build --prefix frontend
```

`bin/ci` runs setup → rubocop → bundler-audit → importmap audit → brakeman → `bin/rails test` → seed replant. GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs the same scans plus `npm audit --audit-level=high` and a frontend build.

Development admin (password is never committed):

```sh
ADMIN_EMAIL=admin@example.test ADMIN_PASSWORD='...' bin/rails db:seed
```

`db/seeds.rb` is a no-op outside `development`.

## Authentication and CSRF flow

This is the part that spans the most files. Rails' native session generator, adapted to a cross-origin SPA.

- [app/controllers/concerns/authentication.rb](app/controllers/concerns/authentication.rb) is included in `ApplicationController`, so **every controller requires authentication by default**. Opt out per-action with `allow_unauthenticated_access only: :create` (a wrapper around `skip_before_action`).
- Sessions are `Session` rows; the id rides in a signed, httponly, `same_site: :lax` permanent cookie. [app/models/current.rb](app/models/current.rb) exposes `Current.session` / `Current.user`.
- `ApplicationController` inherits `ActionController::Base` (**not** `::API`) on purpose — CSRF protection stays on. The SPA calls `GET /api/v1/csrf` once, caches the token in memory, and sends `X-CSRF-Token` on every non-GET ([frontend/src/services/api.js](frontend/src/services/api.js)). All fetches use `credentials: 'include'`.
- CORS is configured in [config/application.rb](config/application.rb): `/api/*` only, `credentials: true`, origin from `FRONTEND_ORIGIN` (default `http://localhost:5173`).
- The Vite dev proxy ([frontend/vite.config.js](frontend/vite.config.js)) forwards `/api` to :3000 **and overwrites the `Origin` header to `http://localhost:3000`** so requests look same-origin to Rails' forgery protection. If you change ports or the proxy, both CSRF and CORS break together.
- Login is rate limited (10 per 3 minutes) via Rails' `rate_limit`, which uses the cache store.

## Authorization

Pundit, with `pundit_user` mapped to `Current.user`. Roles are a validated string enum on `User` (`member` default, `admin`). Policies live in [app/policies/](app/policies/); the dashboard uses a headless policy — `authorize :dashboard, :show?` resolves to `DashboardPolicy`. `ApplicationPolicy` denies everything by default, so new policies must explicitly allow.

## API conventions

- Everything under `namespace :api { namespace :v1 }`; there is no root route and no server-rendered UI.
- Errors are always `{ error: "…" }` with a real status code. **Error messages are written in Indonesian** (see `ApplicationController` rescues, `SessionsController`, `Authentication#request_authentication`) — match that language when adding endpoints.
- `ApplicationController` rescues `Pundit::NotAuthorizedError` → 403 and `InvalidAuthenticityToken` → 422 globally; controllers don't repeat that.

## Frontend structure

- [frontend/src/router.js](frontend/src/router.js) guards `meta.requiresAdmin` routes by awaiting `currentUser()` (a `GET /api/v1/session` that maps 401 → `null`) — the guard is an API round trip, not client state. There is no store; views fetch through `apiFetch`.
- `meta.layout === 'admin'` suppresses the public header in `App.vue`; admin screens wrap themselves in [AdminLayout.vue](frontend/src/components/admin/AdminLayout.vue).
- Tailwind 4 with CSS-first config in [frontend/src/style.css](frontend/src/style.css): `@theme` defines `brand-*`, `gray-*`, `success-*`, `error-*` and `font-outfit`, plus a `dark` custom variant driven by a `.dark` class on `<html>` (toggled in `AdminLayout` and persisted to `localStorage`). Use these tokens, not stock Tailwind palette names.
- Icons come from `@lucide/vue`.

## Vestigial Rails asset stack

`app/javascript/`, `app/views/layouts/`, importmap, Turbo, Stimulus, Propshaft and jbuilder come from the Rails generator and are unused by the SPA. The mailer views (`app/views/passwords_mailer/`) are real but currently have no controller wired to them. Don't add UI there.

## Local environment notes

Ruby 4.0.6 ([.ruby-version](.ruby-version)), Node 22 ([.nvmrc](.nvmrc)), PostgreSQL 17. On Windows, [.bundle/config](.bundle/config) pins the `pg` native build to the PostgreSQL 17 `pg_config.exe`. `Gemfile.lock` intentionally lists darwin, linux and `x64-mingw-ucrt` platforms — some bundler platform operations drop the darwin entries, which would break other contributors; check the `PLATFORMS` block before committing a lockfile change.
