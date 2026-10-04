# Engineer quick start

This guide takes a new engineer from a fresh checkout to a working local LMS.
It assumes Docker Desktop is installed and running.

The public marketing site is part of this same Rails app. `/` opens the homepage
for visitors and prioritizes the console/workspace for signed-in accounts.
`/welcome` always shows the public page; `/app` opens the workspace. The built-in template is live
by default, including on new deployments. Seeds create an editable starter draft;
publish it in **Console → Website** to replace the default. See the
[CMS guide](WEBSITE_CMS.md) before first publication or changing its content model.
The versioned default lives in `config/website_default.json`, captured from the
approved published page. It ships with the app and uses bundled images, not local
upload IDs. Changing database drafts does not change this file or existing live pages.

## 1. Start the stack

From the `lms` directory:

```bash
cp .env.example .env
docker compose up --build
```

Keep that terminal open. The first build installs gems, prepares PostgreSQL,
runs migrations, seeds development accounts, compiles CSS, and starts the job
worker and Nginx.

In another terminal, confirm that every service is running:

```bash
docker compose ps
```

The `db`, `web`, and `nginx` services should report healthy. Open
<http://localhost:3001> and sign in with one of the accounts listed in the
[README](../README.md).

## 2. Know the request path

```text
Browser :3001
    |
    v
Nginx :80
    |
    v
Puma / Rails web:3000
    |
    +--> PostgreSQL db:5432
    +--> Mailpit mailpit:1025
    +--> Solid Queue jobs
```

Nginx is the only web service published on port 3001. Its configuration is in
`docker/nginx/default.conf`. It forwards the original host, client address,
scheme, and WebSocket upgrade headers to Rails.

## 3. Edit and reload

The repository is bind-mounted at `/rails` inside the application containers.
Most changes need no image rebuild:

- Ruby and ERB changes reload through Rails development mode.
- Stimulus changes load after a browser refresh.
- Tailwind source changes are rebuilt by the `css` watcher.
- Database migrations must be run explicitly.

Run a new migration with:

```bash
docker compose exec web bin/rails db:migrate
```

Rebuild the image after changing `Gemfile`, `Gemfile.lock`, `Dockerfile.dev`, or
an operating-system dependency:

```bash
docker compose up -d --build
```

Recreate the application containers after changing `.env`:

```bash
docker compose up -d --force-recreate web jobs css
```

Restart Nginx after editing its configuration:

```bash
docker compose exec nginx nginx -t
docker compose restart nginx
```

## 4. Find the relevant code

| Work | Start here |
| --- | --- |
| Route or URL | `config/routes.rb` |
| Request handling | `app/controllers/` |
| Database rules and relationships | `app/models/` |
| Authorization | `app/policies/` and `app/models/permission.rb` |
| Multi-record workflow | `app/services/` |
| Background work | `app/jobs/` |
| Email | `app/mailers/` and `app/views/*_mailer/` |
| Page markup | `app/views/` |
| Browser behavior | `app/javascript/controllers/` |
| Shared styling | `app/assets/tailwind/application.css` |
| Schema changes | `db/migrate/` |
| Tests | `test/` |

The application uses ERB and Hotwire rather than React. A controller action
loads records and authorizes the request, an ERB view renders the response,
Turbo updates navigation and forms, and a small Stimulus controller handles any
browser-only state.

## 5. Respect tenant and permission boundaries

Organization-owned records must be loaded through `Current.organization` or an
association already scoped to it. Do not load a tenant-owned record globally
and check its organization afterward.

Policies check permission keys, not display names for roles. When adding a
protected action:

1. Add its key to `Permission::CATALOG` and the correct permission group.
2. Grant it to the intended built-in role in the RBAC seed workflow.
3. Authorize the controller action with Pundit.
4. Scope index queries with the policy scope.
5. Test allowed access, denied access, and cross-organization access.

Run `bin/rails db:test:prepare` after changing the permission catalog or RBAC
seeds.

## 6. Work with the database and email

Open a Rails console:

```bash
docker compose exec web bin/rails console
```

Open PostgreSQL directly:

```bash
docker compose exec db psql -U lms -d lms_development
```

The values may differ if you changed `.env`. Mail generated in development is
captured at <http://localhost:8025>. No message leaves your machine through
Mailpit.

## 7. Run checks before handing off work

Run focused tests while developing, then run the complete check:

```bash
docker compose exec web bin/rails test test/integration/example_test.rb
docker compose exec web bin/rails test
docker compose exec web bin/rails test:system
docker compose exec web bin/ci
```

For infrastructure-only changes, validate the affected configuration as well:

```bash
docker compose config --quiet
docker compose exec nginx nginx -t
```

## 8. Diagnose common local problems

Inspect current state and logs:

```bash
docker compose ps
docker compose logs --tail=100 web nginx jobs css
```

If port 3001 is already occupied, stop the other process or change the host-side
port in `compose.yaml`. Do not change Rails from port 3000 unless you also update
the Nginx upstream.

If a CSS change does not appear, confirm that the `css` service is running and
refresh the page without the browser cache. If a new gem is missing, rebuild the
application image. If a migration is pending, run `db:migrate` or `db:prepare`.

## 9. Stop or reset development

Stop containers while keeping the database:

```bash
docker compose down
```

Reset the database only when local data can be discarded:

```bash
docker compose down --volumes
docker compose up --build
```

Read [Architecture and repository structure](ARCHITECTURE.md) before changing a
cross-cutting area such as authentication, authorization, tenancy, quiz
grading, notifications, or background jobs.
