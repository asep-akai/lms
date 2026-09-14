# LMS

A multi-tenant learning management system built with Rails, HotcoQueue.

This repository currently implements the Phase 1 platform foundation:

- Separate Devise authentication for application users and console administrators
- A dedicated, permission-gated `/console`
- Isolated organizations with active/suspended states
- Organization memberships
- Protected Admin, Teacher, and Student roles
- Custom roles backed by explicit permissions
- Cross-organization access checks
- Administrative audit events
- Docker Compose development environment

Course delivery and enrollment are intentionally deferred to the next product phase.

## Start with Docker

Docker Compose runs PostgreSQL, Rails, Solid Queue, the Tailwind watcher, and Mailpit.

```bash
docker compose up --build
```

Open:

- Application: <http://localhost:3000>
- Development email: <http://localhost:8025>

The development console administrator and example organization owner are created automatically:

```text
Email: admin@example.com
Password: change-me-in-development

Application: http://localhost:3000/users/sign_in
Email: owner@example.com
Password: change-me-in-development

Console: http://localhost:3000/console/login
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

An organization administrator adds a member by name and email. Existing users receive a membership in the organization. New users receive a password-reset email, delivered asynchronously, which acts as their account activation link during Phase 1.

## Production direction

The generated production `Dockerfile` is suitable as the base for a Kamal deployment. PostgreSQL should be private, backed up off the VPS, and tested through periodic restores. The Compose file is intended for local development, not production.
