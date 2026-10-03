# LMS

LMS is a multi-tenant learning management system built as a server-rendered
Ruby on Rails application. It uses PostgreSQL for application data, Hotwire for
browser interactions, Solid Queue for background work, and Nginx as the local
reverse proxy.

## What the application includes

- Separate sign-in areas for organization users and platform administrators
- Organization-scoped roles and permissions with Pundit authorization
- User, student, organization, and console administrator management
- Courses organized into sections containing materials and quizzes
- Materials with formatted text, images, and linked video
- Quiz authoring, resumable attempts, time limits, retakes, grading, AI-assisted
  analysis, audio transcription, and published evaluation results
- Course progress and per-module completion tracking
- PDF certificate generation and controlled publication
- Class scheduling, calendars, class history, reschedule requests, and feedback
- Assignments with files, student submissions, deadlines, and teacher comments
- Direct messages between users with a class-based relationship
- In-app notifications for students and teachers
- Organization support tickets with console escalation
- Email previews through Mailpit and administrative audit history

The browser-facing application and its backend are one Rails service. There is
no separate React application or public API.

## Documentation

- [Engineer quick start](docs/ENGINEER_QUICKSTART.md)
- [User quick start](docs/USER_QUICKSTART.md)
- [Architecture and repository structure](docs/ARCHITECTURE.md)
- [Production deployment with Nginx](docs/PRODUCTION_DEPLOYMENT.md)
- [Production backups, restore drills, and rollback](docs/PRODUCTION_RECOVERY.md)
- [Pre-hosting implementation and operator commands](docs/PRE_HOSTING_IMPLEMENTATION.md)
- [Deployment handoff for Codex agents](docs/CODEX_DEPLOYMENT.md)
- [Repository conventions](AGENTS.md)

## Start the application with Docker

You need Docker Desktop on macOS. Confirm that Docker is running:

```bash
docker info
```

Create your local environment file and start the stack:

```bash
cp .env.example .env
docker compose up --build
```

Open these addresses:

| Service | Address |
| --- | --- |
| LMS | <http://localhost:3001> |
| Mailpit inbox | <http://localhost:8025> |
| PostgreSQL | `localhost:5432` |

Nginx owns `localhost:3001` and proxies requests to Rails at `web:3000` on the
private Compose network. Rails is not published directly to the host.

The default development accounts are:

```text
Organization user
URL: http://localhost:3001/users/sign_in
Email: owner@example.com
Password: change-me-in-development

Console administrator
URL: http://localhost:3001/console/login
Email: admin@example.com
Password: change-me-in-development
```

These accounts are for local development. Set different credentials before
sharing an environment.

Stop the stack without removing database data:

```bash
docker compose down
```

## Local services

| Service | Purpose |
| --- | --- |
| `nginx` | Public local entry point on port 3001 and reverse proxy to Rails |
| `web` | Puma and the Rails application on the private port 3000 |
| `db` | PostgreSQL database, published locally on port 5432 |
| `jobs` | Solid Queue background worker |
| `css` | Tailwind CSS watcher |
| `mailpit` | Local SMTP server and browser inbox |

Source files are bind-mounted into the Rails containers. Ruby, ERB, JavaScript,
and CSS edits normally appear without rebuilding the image. Rebuild when the
Gemfile, Dockerfile, or system packages change.

## Environment configuration

`.env.example` lists the supported local settings. The most important values
are:

- PostgreSQL database name and credentials
- Development seed account names, email addresses, and passwords
- Mailpit SMTP host and port
- `OPENAI_API_KEY`, `OPENAI_MODEL`, and `OPENAI_TRANSCRIPTION_MODEL` for AI-assisted quiz analysis
- Default organization name, slug, and locale

After changing `.env`, recreate the application containers so Compose passes
the new values into their processes:

```bash
docker compose up -d --force-recreate web jobs css
```

Never commit `.env`, `config/master.key`, production database credentials, or
API keys.

## Useful commands

```bash
# Show container state
docker compose ps

# Follow Rails, job worker, and proxy logs
docker compose logs -f web jobs nginx

# Prepare or seed the database
docker compose exec web bin/rails db:prepare
docker compose exec web bin/rails db:seed

# Open a Rails console
docker compose exec web bin/rails console

# Run checks
docker compose exec web bin/rails test
docker compose exec web bin/rails test:system
docker compose exec web bin/rubocop
docker compose exec web bin/brakeman --no-pager
docker compose exec web bin/ci

# Validate Nginx configuration
docker compose exec nginx nginx -t
```

## Data and uploaded files

PostgreSQL data is stored in the `postgres_data` Docker volume. Active Storage
uses the configured local disk service in development. Running
`docker compose down` preserves both bind-mounted project files and the named
database volume.

Removing the volume deletes local database data:

```bash
docker compose down --volumes
```

Only run that command when you intend to reset the local database.

## Production direction

The development Compose file is not a production deployment definition. The
repository includes a separate production Compose template, host-level Nginx
templates, persistent PostgreSQL and Active Storage volumes, and environment
placeholders. Follow the [production deployment runbook](docs/PRODUCTION_DEPLOYMENT.md)
before exposing the application. It covers host preparation, secrets, Nginx/TLS
renewal, administrator creation, updates, and launch checks. Production now has
configurable senders, startup validation, a separate non-superuser application
database role on fresh volumes, and rotating logs. `bin/production` provides
preflight, health, administrator bootstrap, backup, fresh-project restore, and
deployment commands. The [implementation record](docs/PRE_HOSTING_IMPLEMENTATION.md)
explains each step and the optional restic/systemd templates. Operators must
still supply real services/secrets, install schedules, and verify the VPS;
checking out the repository does not provision infrastructure.
