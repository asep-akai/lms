# LMS architecture and project structure

This document describes the current application, the boundaries between its
subsystems, the tools it uses, and where each kind of code belongs. It reflects
the implemented code rather than a future product plan.

## 1. System overview

LMS is a server-rendered Ruby on Rails monolith backed by PostgreSQL. Rails owns
HTML rendering, authentication, authorization, persistence, email, background
jobs, and asset delivery. The browser receives ERB-generated HTML and uses
Hotwire for navigation and small interactive behaviors.

```text
Browser
  |
  | HTTP / Turbo requests
  v
Puma -> Rails routes -> Controllers -> Pundit policies
                         |                 |
                         v                 v
                    Services          RBAC queries
                         |                 |
                         +-------> Active Record
                                      |
                                      v
                                  PostgreSQL

Rails -> Active Job -> Solid Queue worker -> PostgreSQL
Rails -> Action Mailer -> SMTP -> Mailpit in development
```

There is one deployable application, not separate frontend and backend
services. The internal layers still have distinct responsibilities:

- Controllers coordinate HTTP requests.
- Policies decide whether the current identity may perform an action.
- Models define data relationships, validation, and small domain rules.
- Services coordinate multi-record workflows and infrastructure operations.
- Views render HTML.
- Stimulus controllers provide focused browser behavior.
- Jobs run deferred or scheduled work.

## 2. Security domains

The application deliberately has two identity types and two login areas.

### Application users

`User` records sign in through `/users/sign_in`. A user can belong to one or
more organizations through `Membership`. Organization roles and permissions
are evaluated within a specific organization.

After login:

- A user with one active organization is redirected directly to it.
- A user with multiple active organizations chooses one.
- A user can only reach records through an active membership.
- Students only see courses in which their membership is enrolled.

Public registration is disabled at the routing and controller layers. Users
are created through the console or organization membership management.

### Console administrators

`Admin` records use the separate `/console/login` session. They manage the LMS
installation: organizations, global users, console administrators, and global
console roles.

Console administrators do not become organization members and cannot receive
organization-only permissions. Organization members cannot receive
console-only permissions. The filtering is enforced in role forms, controller
parameter handling, and authorization checks.

### Current request context

`Current` is an `ActiveSupport::CurrentAttributes` object containing the
request's identity, organization, and membership. Organization controllers set
this context before loading tenant-owned records. Helpers and policies read the
same context.

## 3. Multi-tenancy

Tenants share one PostgreSQL schema. `organizations.id` is the tenant boundary
for organization-owned records.

Isolation is implemented through application code:

- Organization routes use a slug, such as `/organizations/example-school`.
- `Organizations::BaseController` verifies an active membership before any
  nested organization action runs.
- Nested controllers load records through `Current.organization`, for example
  `Current.organization.courses.find(params[:id])`.
- Pundit scopes constrain list queries to the current organization or enrolled
  membership.
- Model validations prevent role assignments and course enrollments from
  crossing organization boundaries.

PostgreSQL row-level security is not currently enabled. Correct controller and
policy scoping therefore remains a critical invariant and should be covered by
tests whenever a tenant-owned model is added.

## 4. Data model

```text
User --< Membership >-- Organization --< Course
  |                         |               |
  |                         |               v
  |                         |        CourseEnrollment
  |                         |               |
  |                         +--< Role       v
  |                               |      Membership
  |                               v
  +--< RoleAssignment >-- RolePermission >-- Permission
  |
Admin --< RoleAssignment >-- global Role --< RolePermission >-- Permission

AuditEvent -> optional Organization
AuditEvent -> polymorphic actor (User or Admin)
AuditEvent -> polymorphic auditable record
```

### Core records

| Model | Responsibility |
| --- | --- |
| `User` | Application identity, authentication state, memberships, and organization role assignments. |
| `Admin` | Console identity and global role assignments. |
| `Organization` | Tenant root, slug, status, locale, timezone, members, roles, courses, and audit events. |
| `Membership` | Connects one user to one organization and records active or suspended status. |
| `Role` | Named bundle of permissions. Global roles belong to no organization; application roles belong to one. |
| `Permission` | Canonical permission catalog, console/organization boundaries, and display groups. |
| `RolePermission` | Join between roles and permissions. |
| `RoleAssignment` | Polymorphic assignment of a role to a `User` or `Admin`, with scope validation. |
| `Course` | Organization-owned course metadata: name and description. |
| `CourseEnrollment` | Connects a course to a Student membership in the same organization. |
| `AuditEvent` | Immutable record of significant administrative actions. |

### RBAC rules

Policies ask for permission keys rather than checking role names. Built-in role
keys still have domain meaning where required: `admin` protects the final
active organization administrator and `student` determines course enrollment
eligibility.

Permission groups are divided into:

- Console-only: console access and platform management of organizations,
  users, and administrators.
- Organization-only: organization settings, memberships, courses,
  enrollments, and audit history.
- Shared role-management keys: used in the appropriate role scope on either
  side.

Organization role forms cannot assign console-only permissions. Console role
forms cannot assign organization-only permissions.

## 5. Main request flows

### Organization access

1. Devise authenticates a `User`.
2. `DashboardController` loads active organizations through
   `OrganizationPolicy::Scope`.
3. One organization causes an immediate redirect; multiple organizations
   render the chooser.
4. Organization controllers establish `Current.organization` and
   `Current.membership`.
5. Pundit authorizes the requested operation.

### Creating an organization

1. A console administrator selects an existing user as owner.
2. `OrganizationProvisioner` creates the organization in a transaction.
3. It creates the built-in Organization administrator, Teacher, and Student
   roles.
4. It grants organization-management permissions to the administrator role.
5. It creates the owner's membership and role assignment.
6. It records an audit event.

### Managing members

An authorized organization member can add an existing user or create a new
user with an initial password. Membership role assignments are constrained to
roles from the same organization. Password replacement never reveals the old
password. The last active organization administrator cannot be removed,
suspended, or stripped of the administrator role.

### Courses and enrollment

Authorized roles can create, edit, delete, and list all organization courses.
Enrollment management lists active memberships carrying the Student role.
`CourseEnrollment` validates both the organization boundary and Student role.
Ordinary students receive a policy scope containing only their enrolled
courses and cannot open an unenrolled course directly.

### Auditing

`AuditRecorder` writes `AuditEvent` rows for account, organization, membership,
role, course, and enrollment changes. Organization audit pages show the most
recent 100 events. Persisted audit records are read-only through the model.

### Recovery sweep

`RecoverySweep` removes role assignments whose assignee no longer belongs to
the role's scope. `RecoverySweepJob` exposes this as an Active Job. Production
schedules it daily at 03:00 through Solid Queue recurring tasks.

## 6. Frontend architecture

The UI is server-rendered ERB; there is no React, Vue, Node package manager, or
client-side state store.

- Turbo accelerates navigation, form submissions, and frame responses.
- Stimulus controls shared modal behavior.
- A small Turbo confirmation adapter renders destructive confirmations with
  the native `<dialog>` element.
- Tailwind CSS v4 is compiled through `tailwindcss-rails`.
- Reusable design utilities such as `btn-primary`, `field`, `card`, and
  `modal-panel` live in `app/assets/tailwind/application.css`.
- Propshaft serves fingerprinted assets.
- Importmap loads JavaScript modules without a bundling step.

The application and console use separate layouts. Authentication pages also
have dedicated layouts. Shared partials own validation errors, permission
groups, and modal markup.

## 7. Background services and storage

- Solid Queue stores jobs in PostgreSQL and is run by the `jobs` Compose
  service during development.
- Solid Cache is configured as the production cache store.
- Solid Cable is configured for production Action Cable, although the app has
  no product-specific channels yet.
- Active Storage is configured for local disk, but no current feature attaches
  files. Image variants are explicitly disabled.
- Action Mailer sends through SMTP. Development points to Mailpit.
- `ApiTransport` provides HTTP timeout and connection-error normalization for
  future integrations; no current feature calls an external API through it.

## 8. Tools and dependencies

### Runtime and framework

| Tool | Use |
| --- | --- |
| Ruby 3.3.8 | Application language. |
| Rails 8.1.3.1 | MVC framework, routing, Active Record, jobs, mail, and tests. |
| PostgreSQL 18 (development image) | Primary relational database and development job storage. |
| Puma | Rails application server. |
| Bootsnap | Faster Ruby boot through load-path and bytecode caches. |
| Thruster | Production HTTP proxy/cache/compression wrapper in the container command. |

### Authentication and authorization

| Tool | Use |
| --- | --- |
| Devise | Separate `User` and `Admin` authentication, password recovery, and sessions. |
| Pundit | Policy authorization and scoped queries. |
| bcrypt | Password hashing dependency. |
| Custom RBAC models | Roles, permissions, assignments, scope separation, and permission groups. |

### Browser and assets

| Tool | Use |
| --- | --- |
| ERB | Server-rendered HTML templates. |
| Turbo | Navigation, form handling, and modal frame requests. |
| Stimulus | Small JavaScript controllers. |
| Importmap | Browser module loading without Webpack, Vite, or npm. |
| Tailwind CSS v4 | Utility-based styling compiled by Rails. |
| Propshaft | Rails asset pipeline. |
| Jbuilder | Installed for JSON views, though there is no application API yet. |

### Data, jobs, and communication

| Tool | Use |
| --- | --- |
| Active Record | PostgreSQL persistence, associations, validations, and transactions. |
| Solid Queue | PostgreSQL-backed Active Job execution and recurring work. |
| Solid Cache | PostgreSQL-backed production caching. |
| Solid Cable | PostgreSQL-backed production Action Cable adapter. |
| Action Mailer | Password recovery and account email delivery. |
| Mailpit | Local SMTP server and browser inbox at port 8025. |
| Active Storage | Configured local file storage; not used by current features. |
| Net::HTTP | Standard-library HTTP client wrapped by `ApiTransport`. |

### Development, testing, and delivery

| Tool | Use |
| --- | --- |
| Docker Compose | Local PostgreSQL, Rails, jobs, Tailwind watcher, and Mailpit services. |
| Dockerfile.dev | Development image with Ruby build tools, Chromium, PostgreSQL headers, and libvips. |
| Dockerfile | Multi-stage production image running as a non-root user. |
| Foreman | Runs Puma, Tailwind, and jobs together outside Compose via `bin/dev`. |
| Minitest | Model, service, and integration tests. |
| Fixtures | Deterministic test data. |
| Capybara + Selenium + Chromium | Browser-level system tests. |
| WebMock | Blocks unintended outbound network access in tests. |
| RuboCop Rails Omakase | Ruby style checks. |
| Brakeman | Rails static security analysis. |
| bundler-audit | Gem vulnerability checks. |
| importmap audit | Imported JavaScript vulnerability checks. |
| GitHub Actions | Hosted lint, security, integration, and system-test jobs. |
| Dependabot | Automated dependency update configuration. |
| Kamal | Available production deployment tooling; deployment is not yet fully configured. |
| Ruby LSP | Ruby language intelligence in VS Code. |
| htmlbeautifier | ERB formatting. |

## 9. Repository structure

```text
lms/
├── app/
│   ├── assets/               Tailwind source, compiled CSS, and images
│   ├── channels/             Action Cable connection base
│   ├── controllers/          HTTP coordination and namespace boundaries
│   │   ├── concerns/         Shared modal rendering behavior
│   │   ├── console/          Platform-console controllers
│   │   ├── organizations/    Organization-scoped controllers
│   │   └── users/            User account customization
│   ├── helpers/              View helpers and permission checks
│   ├── javascript/           Importmap entry point and Stimulus controllers
│   ├── jobs/                 Active Job classes
│   ├── mailers/              Action Mailer base
│   ├── models/               Domain records and relationships
│   ├── policies/             Pundit authorization and query scopes
│   ├── services/             Multi-record workflows and infrastructure wrappers
│   └── views/                ERB templates by controller namespace
├── bin/                      Versioned application and quality commands
├── config/                   Routes, environments, adapters, initializers, and CI
├── db/                       Migrations, schemas, and seeds
├── docs/                     Maintained architecture documentation
├── lib/                      Extension point for library code and Rake tasks
├── public/                   Static public files and error pages
├── storage/                  Ignored local Active Storage data
├── test/                     Minitest, fixtures, support, and browser tests
├── .github/                  CI and dependency automation
├── .vscode/                  Recommended editor extensions and formatting settings
├── compose.yaml              Local multi-container environment
├── Dockerfile.dev            Development image
├── Dockerfile                Production image
├── Gemfile / Gemfile.lock    Ruby dependency declarations and lockfile
├── Procfile.dev              Foreman development processes
└── README.md                 Setup and operational quick start
```

### `app/controllers`

- `ApplicationController` installs Pundit, modal support, modern-browser
  requirements, and the shared unauthorized response.
- `AppController` requires a signed-in `User` and exposes application context.
- `DashboardController` handles organization selection and direct entry.
- `OrganizationsController` renders the organization dashboard and settings.
- `Organizations::BaseController` is the tenant gate for nested resources.
- `Organizations::MembershipsController` manages members, roles, and password
  replacement.
- `Organizations::RolesController` manages organization RBAC while rejecting
  console permissions.
- `Organizations::CoursesController` manages courses and Student enrollments.
- `Organizations::AuditEventsController` renders tenant audit history.
- `Console::BaseController` requires an authenticated, authorized `Admin` and
  verifies policy scopes for index actions.
- Other `Console::*Controller` classes manage platform organizations, users,
  administrators, and global roles.
- `Users::RegistrationsController` permits account updates but blocks public
  account creation.

### `app/models`

Model files own associations, validation, normalized identifiers, active-state
rules, permission lookup, and cross-scope integrity checks. Complex workflows
that touch several models are kept in services instead.

### `app/policies`

Each protected resource has a Pundit policy. Action methods map to permission
keys; nested `Scope` classes constrain collection queries. When adding a new
action, add the permission to `Permission::CATALOG`, assign it through the
appropriate seed role, and cover both allowed and denied paths.

### `app/services`

- `OrganizationProvisioner` atomically creates a tenant and its initial RBAC.
- `RbacSeeder` synchronizes the permission catalog and built-in console role.
- `AuditRecorder` centralizes audit-event construction.
- `RecoverySweep` repairs invalid role assignments.
- `ApiTransport` standardizes low-level HTTP timeouts and connection failures.

### `app/views` and `app/javascript`

Views mirror controller namespaces. Shared partials contain reusable form and
modal pieces. JavaScript is intentionally small: the entry point imports Turbo,
Stimulus controllers, and the confirmation adapter. New behavior should prefer
HTML and Turbo first, then a narrowly-scoped Stimulus controller when browser
state is required.

### `config`

- `routes.rb` defines the two authentication scopes, tenant resources, console
  resources, and health endpoint.
- `database.yml` configures PostgreSQL and production database roles.
- `queue.yml`, `cache.yml`, and `cable.yml` configure Solid adapters.
- `recurring.yml` schedules queue cleanup and the recovery sweep in production.
- `importmap.rb` declares browser JavaScript modules.
- `environments/` contains development, test, and production behavior.
- `initializers/` configures Devise, parameter filtering, assets, and security
  policy hooks.
- `ci.rb` defines the local `bin/ci` sequence.

### `db`

- `migrate/` is the source of truth for schema changes.
- `schema.rb` is the current primary database snapshot.
- `cache_schema.rb` and `cable_schema.rb` define Solid Cache and Solid Cable
  storage.
- `seeds.rb` synchronizes permissions and optionally provisions development
  identities and an example organization from environment variables.

### `test`

- `models/` covers validations, permission behavior, and record invariants.
- `services/` covers orchestration and recovery behavior.
- `integration/` covers authentication, authorization, tenant isolation,
  account administration, course enrollment, and rendered controls.
- `system/` exercises modal behavior in Chromium.
- `fixtures/` provides stable base identities and organizations.
- `support/test_rbac.rb` creates the canonical roles and permissions for each
  test.
- `test_helper.rb` enables fixtures, Devise helpers, one-worker execution, and
  outbound HTTP blocking.

### Root operational files

- `compose.yaml` runs `db`, `web`, `jobs`, `css`, and `mailpit`. Source code is
  bind-mounted so Rails and Tailwind see local edits immediately.
- `.env.example` documents local configuration. Real `.env` files are ignored.
- `Dockerfile.dev` supplies the local runtime and browser-test dependencies.
- `Dockerfile` builds the production image in two stages and runs it as an
  unprivileged user.
- `Procfile.dev` describes the non-Compose development process group.
- `.github/workflows/ci.yml` runs hosted security, lint, Rails, and browser jobs.
- `.vscode/` configures Ruby LSP and ERB formatting recommendations.

## 10. Configuration and secrets

Development configuration comes from Compose defaults or a local `.env` based
on `.env.example`. Important values include PostgreSQL connection details,
SMTP host and port, initial console administrator credentials, optional initial
application user credentials, and example organization settings.

Production additionally requires `RAILS_MASTER_KEY`, database credentials,
real host/SSL configuration, and SMTP delivery settings. `.env` files and
`config/*.key` are ignored and must not be committed.

## 11. Verification workflow

The primary commands are:

```bash
docker compose up --build
docker compose exec web bin/rails db:prepare
docker compose exec web bin/rails test
docker compose exec web bin/rails test:system
docker compose exec web bin/ci
```

`bin/ci` runs setup, RuboCop, gem and importmap audits, Brakeman, Rails tests,
browser tests, and seed verification. It is the final local check before a
change is considered complete.

## 12. Current product boundary

Implemented:

- Separate application and console authentication.
- Shared-schema organizations and memberships.
- Permission-based roles with console/organization separation.
- User and administrator account management with password replacement.
- Organization settings, member management, role management, and audit history.
- Course metadata, Student enrollment, and enrollment-limited course access.
- Docker-based development and automated verification.

Not implemented yet:

- Lessons, modules, files, video, or other course content.
- Assignments, submissions, grading, completion, or progress tracking.
- Teacher-specific course ownership or teaching workflows.
- Notifications beyond Devise account email.
- A public JSON API or third-party integration.
- Production object storage, full deployment configuration, monitoring, and
  backup automation.
