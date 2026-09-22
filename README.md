# LMS

A multi-tenant learning management system built with Ruby on Rails and PostgreSQL.

The current application includes:

- Separate Devise authentication for application users and console administrators
- A dedicated, permission-gated `/console`
- Isolated organizations with active/suspended states
- Organization memberships
- Built-in Organization administrator, Teacher, and Student roles
- Custom roles backed by explicit permissions
- Organization-scoped course creation and management
- Student enrollment and enrollment-limited course access
- Cross-organization access checks
- Administrative audit events
- Docker Compose development environment

Courses currently contain a name, description, and student enrollments. Lessons,
learning materials, submissions, and grading are not implemented yet.

For a detailed system map, data model, request flows, and directory guide, see
[Architecture and project structure](docs/ARCHITECTURE.md).

## Start with Docker

Docker Compose runs PostgreSQL, Rails, Solid Queue, the Tailwind watcher, and Mailpit.

```bash
docker compose up --build
```

Open:

- Application: <http://localhost:3001>
- Development email: <http://localhost:8025>

The development console administrator and example organization owner are created automatically:

```text
Email: admin@example.com
Password: change-me-in-development

Application: http://localhost:3001/users/sign_in
Email: owner@example.com
Password: change-me-in-development

Console: http://localhost:3001/console/login
Email: admin@example.com
Password: change-me-in-development
```

These credentials are for local development only. Change the Compose environment values before sharing a development environment.

The PostgreSQL data is held in the `postgres_data` named volume. To stop the stack without deleting data:

```bash
docker compose down
```

## Configuration

Production requires these secrets or equivalent Rails/Kamal configuration:

- `RAILS_MASTER_KEY`
- `LMS_DATABASE_PASSWORD` or database URLs
- `ADMIN_EMAIL` and `ADMIN_PASSWORD` for the initial console seed
- Optional `APP_USER_EMAIL` and `APP_USER_PASSWORD` for an initial organization owner
- SMTP host and credentials

Never commit a populated `.env` file or `config/master.key`.

### Gemini analysis

Automatic quiz analysis uses the Gemini API. Copy `.env.example` to `.env`, then add your key:

```text
GEMINI_API_KEY=your-key-here
GEMINI_MODEL=gemini-2.5-flash
```

Recreate the web container after changing these values so Compose passes them into Rails:

```bash
docker compose up -d --force-recreate web
```

The application calculates quiz correctness from its own answer key. Gemini receives that grading data and writes an unpublished performance-analysis draft; an authorized reviewer must check and publish it before the student can see it.

## Useful commands

```bash
docker compose run --rm web bin/rails db:prepare
docker compose run --rm web bin/rails db:seed
docker compose run --rm web bin/rails test
docker compose run --rm web bin/rails test:system
docker compose run --rm web bin/brakeman --no-pager
docker compose run --rm web bin/rubocop
```

## Tenancy model

Organizations share one PostgreSQL schema. Tenant-owned records are reached through the current organization, and membership is checked before nested organization controllers run. Application roles belong to one organization; console roles are global. Polymorphic role assignments let both identity types use one permission-based policy system while validation prevents cross-scope assignments.

Console administrators are installation-level operators stored in the separate `admins` table. Organization administrators are ordinary application users who receive the protected organization `admin` role. These concepts and sessions are deliberately separate.

## Invitation flow

An organization administrator adds a member by name and email. Existing users
receive another organization membership without changing their password. New
users receive an initial password chosen by the administrator. Administrators
can later replace that password without seeing its current value, and platform
console administrators can also send Devise password-reset instructions.

## Production direction

The generated production `Dockerfile` is suitable as the base for a Kamal deployment. PostgreSQL should be private, backed up off the VPS, and tested through periodic restores. The Compose file is intended for local development, not production.
