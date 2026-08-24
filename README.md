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
- CORS configuration and Vite development proxy
- Minitest coverage for login and admin authorization

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

For production, configure an SMTP provider with:

```sh
MAILER_FROM=no-reply@example.com
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
SMTP_AUTHENTICATION=plain
SMTP_STARTTLS_AUTO=true
```

Store these values in the deployment platform's secret manager, never in Git.

## Member registration

Public registration is available at `http://localhost:5173/register`. New
accounts always receive the `member` role, require a password of at least 12
characters, and must verify their email with OTP before a session is created.
Administrator accounts are created or promoted separately through trusted
server-side operations such as the development seed.

## Password recovery

The login page links to `http://localhost:5173/forgot-password`. Password
recovery sends a separate six-digit OTP that expires after ten minutes. A
successful reset revokes all existing sessions for the account. Development
reset emails appear in `http://localhost:3000/letter_opener` alongside login and
registration OTP messages.

## Production configuration

Provide the renamed database password environment variable and Rails master
key through your deployment platform. Never commit `.env`, `config/master.key`,
or encrypted credentials generated for a specific deployed application.

## Verification

```sh
bin/rails test
npm run build --prefix frontend
bin/rubocop
```

## Template maintenance

Keep this repository generic. Add reusable infrastructure and UI components
here, but add business-specific models, migrations, and credentials only after
creating a project from the template.
