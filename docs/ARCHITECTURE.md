# LMS architecture and repository structure

This document describes the implemented application, its runtime services, and
where each kind of code belongs. It is a technical map rather than a product
roadmap.

## System overview

LMS is a server-rendered Ruby on Rails monolith backed by PostgreSQL. Rails owns
HTML rendering, authentication, authorization, business workflows, persistence,
email, file attachments, background jobs, and real-time page updates.

```text
Browser
  |
  | HTTP, Turbo, and WebSocket upgrade requests
  v
Nginx :3001 on the host
  |
  | proxy_pass
  v
Puma / Rails web:3000
  |
  +--> Controllers --> Pundit policies --> Models --> PostgreSQL
  |                         |
  |                         +--> Current tenant and membership context
  |
  +--> Services --> OpenAI API, PDF rendering, notifications, and mail
  |
  +--> Active Job --> Solid Queue worker --> PostgreSQL
  |
  +--> Action Mailer --> SMTP --> Mailpit in development
  |
  +--> Active Storage --> local disk in development
```

There is no separate frontend service. ERB views render HTML, Turbo handles
navigation and partial updates, and Stimulus controllers manage focused browser
behavior such as modals, editors, audio recording, timers, search selectors,
live chat, and notification menus.

## Local container topology

`compose.yaml` defines six services:

| Service | Network role |
| --- | --- |
| `nginx` | Publishes `127.0.0.1:3001`, forwards requests to `web:3000`, and preserves proxy and WebSocket headers. |
| `web` | Runs Puma and Rails. Port 3000 is exposed only to the Compose network. |
| `db` | Runs PostgreSQL and publishes `127.0.0.1:5432` for local database tools. |
| `jobs` | Runs the Solid Queue worker from the same application image. |
| `css` | Watches and compiles Tailwind CSS from the same source mount. |
| `mailpit` | Accepts development SMTP on the private port 1025 and publishes its inbox on port 8025. |

The Nginx configuration lives in `docker/nginx/default.conf`. It accepts uploads
up to 100 MB, forwards the original host and scheme, supports WebSocket upgrade
headers, and allows long reads for operations such as AI analysis and file
delivery. Its `/up` health check reaches the Rails health endpoint through the
proxy.

## Identity and security domains

The application has two identity types and two sessions.

### Organization users

`User` records sign in through `/users/sign_in`. A user belongs to organizations
through `Membership` records. Roles and permissions are evaluated within the
current organization.

After sign-in, a user with one active organization enters it directly. A user
with several active organizations chooses one. Public registration is disabled;
authorized administrators create accounts and memberships.

### Console administrators

`Admin` records sign in through `/console/login`. The console manages the LMS
installation, including organizations, application users, console
administrators, console roles, and escalated support tickets.

An `Admin` is not a `User`. Console roles cannot receive organization-only
permissions, and organization roles cannot receive console-only permissions.

### RBAC and Pundit

The authorization model consists of `Role`, `Permission`, `RolePermission`, and
polymorphic `RoleAssignment` records. Policies check permission keys from
`Permission::CATALOG`; they do not rely on editable role names.

Organization and console permission groups are filtered independently. The
built-in organization administrator role receives all organization permissions
and has additional protection so an organization cannot lose its final active
administrator.

Pundit action methods authorize individual operations. Pundit scopes limit the
records returned by index actions. Controller tests should cover the allowed,
denied, and cross-tenant paths for every new protected resource.

### Current request context

`Current` extends `ActiveSupport::CurrentAttributes`. Organization controllers
set the current user, organization, and membership for the request. Policies,
helpers, services, and nested record loading use the same context.

## Multi-tenancy

Organizations share one PostgreSQL schema. Tenant-owned tables reference an
organization either directly or through an organization-owned parent.

Isolation depends on four rules:

1. Organization routes use the organization slug.
2. `Organizations::BaseController` verifies an active membership.
3. Controllers load nested records through `Current.organization` or an
   already-scoped association.
4. Policies and model validations prevent cross-organization access and
   assignments.

PostgreSQL row-level security is not enabled. Application scoping and its tests
are therefore security-critical.

The configured application and organization time zone is Jakarta. Stored
timestamps remain UTC through Rails and PostgreSQL; forms, pages, email, audit
history, certificates, and deadlines convert them to WIB for display.

## Domain model

The main records are grouped below. Join and detail records are listed with the
feature they support.

### Accounts and organizations

| Model | Responsibility |
| --- | --- |
| `User` | Organization-facing Devise identity. |
| `Admin` | Platform-console Devise identity. |
| `Organization` | Tenant root, status, slug, WIB time zone, and owned records. |
| `Membership` | Connects a user to an organization, tracks status and student reschedule quota. |
| `Role`, `Permission` | RBAC definitions. |
| `RolePermission`, `RoleAssignment` | Permission grants and assignments to users or admins. |
| `AuditEvent` | Immutable administrative activity record with polymorphic actor and subject. |

### Courses, content, and progress

| Model | Responsibility |
| --- | --- |
| `Course` | Course name, description, enrollment, and ordered content root. |
| `CourseEnrollment` | Connects an eligible student membership to a course. |
| `CourseSection` | Named, ordered group of course modules. |
| `CourseContent` | Ordered polymorphic placement of a material or quiz in a course section. |
| `CourseProgress` | Aggregates completion for one student and course. |
| `Material` | Article-like course material and card metadata. |
| `MaterialBlock` | Ordered text, image, or video content within a material. |
| `MaterialCompletion` | Student-controlled material completion state. |

### Quizzes and grading

| Model | Responsibility |
| --- | --- |
| `Quiz` | Assessment settings, time limit, and retake quota. |
| `QuizPage`, `QuizPageBlock` | Shared, ordered instructions containing text and images. |
| `QuizQuestion` | Multiple choice, multi-select, short answer, cloze, essay, and audio questions. |
| `QuizAttempt` | Attempt lifecycle, saved navigation position, timing, submission, review, score, and analysis. |
| `QuizAnswer` and response records | Student text, selections, cloze responses, and audio attachments. |
| `QuizAnswerOverride` | Manual correction of an automatically determined result. |
| `QuizAnswerAiGrade` | AI-generated grade data for open-ended answers. |
| `QuizAnswerAiTranscription` | Audio transcription generated for grading. |
| `QuizAnswerFeedback` | Per-answer reviewer or AI feedback. |
| `Certificate` | Published or unpublished certificate generated from a reviewed result. |

`QuizAttemptStarter` starts or resumes attempts and enforces retake rules.
`QuizAttemptTimeoutJob` submits timed-out attempts even when the student has
left the page. `QuizAttemptGrader` calculates deterministic results from stored
answer keys. `QuizAttemptPerformanceAnalyzer` coordinates OpenAI analysis while
keeping its draft unpublished until an authorized reviewer confirms it.

Certificate generation is split into a builder, generator, and PDF renderer so
additional certificate sources and templates can be added without coupling them
to quiz controllers.

### Classes, assignments, and communication

| Model | Responsibility |
| --- | --- |
| `ClassMeeting` | Subject, topic, start time, delivery mode, meeting number, teacher, and online link. |
| `ClassMeetingStudent` | Student assignment for a meeting. |
| `ClassMeetingFeedback` | Student-to-teacher feedback and per-student teacher feedback. |
| `Assignment` | Teacher-created work, deadline, optional source document, and lifecycle. |
| `AssignmentRecipient` | Assignment delivery to a student. |
| `AssignmentSubmission` | Student text, attachments, submission state, and teacher comment. |
| `DirectConversation`, `DirectMessage` | Class-relationship-based messaging and unread tracking. |
| `Notification` | Organization-scoped in-app notification for a student or teacher membership. |
| `SupportTicket`, `SupportMessage` | Organization support conversation, attachments, and console escalation. |

Service objects handle class email, reschedule validation, assignment email,
support email, contact discovery, and in-app notification fan-out. This keeps
controllers focused on HTTP and authorization.

## Request and update flows

### Server-rendered request

1. Nginx forwards the request to Puma.
2. Rails routes it to a controller action.
3. Devise authenticates the relevant identity.
4. The organization base controller establishes tenant context.
5. Pundit authorizes the action and scopes collections.
6. Models or a service object perform the domain operation.
7. ERB renders HTML or a Turbo Stream response.

### Live chat and notifications

Messages and notifications render through Turbo Streams. The application uses
the asynchronous Action Cable adapter in development and Solid Cable in
production. Nginx forwards the required connection upgrade headers. Read state
is stored in PostgreSQL, so unread markers survive navigation and reconnects.

### Email

Action Mailer sends through SMTP. Compose points Rails at Mailpit, where new
class, reschedule, assignment, submission, comment, and support messages can be
inspected without external delivery.

### Uploaded files

Active Storage owns material images, quiz page images, audio answers,
assignment documents, submissions, and support attachments. Development and
the current production configuration use local disk storage. Image variants are
disabled, so code must not assume that Rails can transform uploaded images.

## Frontend architecture

- ERB templates live under `app/views` and mirror controller namespaces.
- Turbo accelerates navigation, submits forms, renders frames, and broadcasts
  live chat and notification updates.
- Stimulus owns browser-only state and progressive behavior.
- Importmap loads JavaScript modules without npm, Webpack, or Vite.
- Tailwind CSS v4 is compiled by `tailwindcss-rails`.
- Shared component utilities live in
  `app/assets/tailwind/application.css`.
- Propshaft fingerprints and serves assets.

Views should use the existing component utilities. New JavaScript belongs in a
narrowly scoped Stimulus controller rather than an inline script.

## Background work, integrations, and documents

- Solid Queue stores and executes jobs through PostgreSQL.
- Solid Cache is the production cache store.
- Solid Cable is the production Action Cable adapter.
- OpenAI is wrapped by `Ai::OpenaiClient`; configuration and provider errors
  have application-specific error classes.
- Prawn generates certificate PDFs through the certificate service boundary.
- `ApiTransport` normalizes HTTP timeouts, connection failures, and JSON API
  requests.

## Repository structure

```text
lms/
├── app/
│   ├── assets/               Tailwind source, compiled CSS, and images
│   ├── channels/             Action Cable connection base
│   ├── controllers/          HTTP actions and namespace boundaries
│   │   ├── concerns/         Shared controller behavior
│   │   ├── console/          Platform-console actions
│   │   ├── organizations/    Tenant-scoped actions
│   │   └── users/            User account customization
│   ├── helpers/              View and authorization helpers
│   ├── javascript/           Importmap entry and Stimulus controllers
│   ├── jobs/                 Solid Queue jobs
│   ├── mailers/              Email preparation
│   ├── models/               Records, relationships, and invariants
│   ├── policies/             Pundit actions and query scopes
│   ├── presenters/           View-facing formatting and calendar logic
│   ├── services/             Workflows, integrations, and document generation
│   └── views/                ERB pages, partials, mail, and Turbo Streams
├── bin/                      Application, setup, formatting, and CI commands
├── config/                   Routes, environments, adapters, and initializers
├── db/                       Migrations, schema snapshots, and seeds
├── docker/nginx/             Local reverse-proxy configuration
├── docs/                     Engineer, user, and architecture documentation
├── public/                   Static public files and error pages
├── storage/                  Ignored local Active Storage files
├── test/                     Unit, service, integration, mailer, and system tests
├── .github/                  CI and dependency automation
├── .vscode/                  Editor recommendations and formatting settings
├── compose.yaml              Local service topology
├── compose.production.yaml   Production web, worker, database, and volumes
├── Dockerfile.dev            Development application image
├── Dockerfile                Production application image
├── Gemfile                   Ruby dependencies
├── Procfile.dev              Non-Compose development process definitions
└── README.md                 Project entry point
```

## Important files and directories

### Controllers

`ApplicationController` installs Pundit and shared modal behavior.
`AppController` requires a signed-in organization user.
`Organizations::BaseController` establishes the tenant boundary.
`Console::BaseController` requires a console administrator and verifies
authorization and policy scopes.

Keep controllers small. When an operation changes several records, sends
notifications, or calls an external service, put that workflow in
`app/services`.

### Models and migrations

Models own associations, validation, normalized values, and compact domain
rules. Migrations in `db/migrate` are the source of truth for schema changes;
`db/schema.rb` is the resulting snapshot. Do not edit the schema snapshot to
create a database change.

### Policies and permissions

Each protected resource has a Pundit policy. Permission keys and display groups
live in `app/models/permission.rb`. RBAC seed services synchronize the catalog
with the database.

### Views, presenters, and JavaScript

Views should format little data themselves. Repeated or non-trivial display
logic belongs in a helper or presenter. Shared form fields and cards belong in
partials. Browser state belongs in a Stimulus controller.

### Configuration

- `config/routes.rb` defines application, organization, and console URLs.
- `config/database.yml` configures PostgreSQL and production database roles.
- `config/queue.yml`, `cache.yml`, and `cable.yml` configure Solid adapters.
- `config/recurring.yml` defines recurring production work.
- `config/importmap.rb` declares JavaScript modules.
- `config/environments/` controls runtime behavior by environment.
- `.env.example` documents local environment variables.

## Testing and verification

The test suite uses Minitest, fixtures, Capybara, Selenium, Chromium, and
WebMock. Tests run with one worker because parallel execution is disabled in
this repository.

Use focused tests while implementing a change, then run:

```bash
docker compose exec web bin/rails test
docker compose exec web bin/rails test:system
docker compose exec web bin/ci
```

`bin/ci` covers style, dependency audits, Brakeman, Rails tests, system tests,
and seed verification. Infrastructure changes should also pass:

```bash
docker compose config --quiet
docker compose exec nginx nginx -t
```

## Production boundary

The repository includes a multi-stage production Dockerfile, Thruster, a
production Compose template, and host-level Nginx templates. The production
template runs Rails, Solid Queue, PostgreSQL, Solid Cache, and Solid Cable with
persistent volumes. Before placing the application on a public VPS, provide:

- A domain and a chosen TLS termination layer
- Production database credentials and automated off-server backups
- Persistent or object storage for Active Storage
- A real SMTP provider
- Rails master key and API secrets outside the repository
- Monitoring, log retention, health checks, and restore testing
- A production Action Cable path that preserves WebSocket upgrade headers

The [production runbook](PRODUCTION_DEPLOYMENT.md) documents host preparation,
HTTP bootstrap, HTTPS and certificate renewal, administrator creation, release
updates, and launch verification. `MAIL_FROM` supplies both application and
Devise senders. Fresh production databases separate the PostgreSQL bootstrap
superuser from the application owner, and the entrypoint validates production
settings before startup. `bin/production` handles checks, backup/restore, and
maintenance-window deployments; optional host timers live in `deploy/systemd`. The
[recovery guide](PRODUCTION_RECOVERY.md) covers consistent backups of databases
and files, off-server retention, isolated restore drills, and rollback decisions.
These procedures require operator setup and verification on the chosen VPS.
The [implementation record](PRE_HOSTING_IMPLEMENTATION.md) tracks preparation
and testing; the [Codex handoff](CODEX_DEPLOYMENT.md) defines agent deployment
stages, secret-handling rules, approval boundaries, and stop conditions.

## Public promotional site

The Rails app also serves a public landing page, independently of the private LMS
layouts and tenant context. `LandingPage` and ordered `LandingSection` records
hold drafts; `LandingPublication` holds the public snapshot and asset references.
`LandingController#home` routes `/` to the console for an admin session, then the
workspace for a user session, otherwise the public page. It preserves flash
messages and uses no-store responses. `/welcome` always serves the public page;
`/app` retains the organization dashboard/chooser. Before the first publication, the public page
renders `LandingPageStarter.default_content`, not editable database drafts. The
starter content comes from the captured publication in `config/website_default.json`,
is shared with seeds and ships in the application image. Its portable section
anchors are remapped to real section records when creating a fresh draft. After
an explicit unpublish, publication history suppresses that default so the page
stays hidden. Public requests do not create CMS records.
Section snapshots include an optional allowlisted illustration key and image
placement. Uploaded Active Storage images take precedence; bundled JPEGs are
Propshaft assets and do not depend on a developer's upload storage. Versioned
asset filenames must be retained while published snapshots reference their keys.
Footer text, copyright, visibility, workspace-link visibility and palette are
draft attributes on `LandingPage`. `LandingNavigationItem#placement` separates
header and footer links, with independent ordering and shared destination checks.
Publication snapshots contain the footer settings and visible links; older
snapshots retain the original footer. Section background presets resolve in the
draft snapshot and remain fixed once published.
The console CMS separates `website.edit` from `website.publish`. See
[Website CMS](WEBSITE_CMS.md) for the code map, access rules and publishing flow.
