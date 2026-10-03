# Production deployment with Nginx and Docker Compose

This runbook describes the production boilerplate included in the repository.
It can be prepared and tested locally before a VPS, domain, SMTP account, or TLS
certificate exists.

This is a single-VPS deployment with planned downtime during updates. It does
not provide high availability, automatic failover, or an installed backup
scheduler. Complete the launch checklist below before accepting real users.
Commands in this guide use Bash on an Ubuntu-style Linux host with systemd.
Run application commands from the repository root, not its parent folder.

See the [pre-hosting implementation record](PRE_HOSTING_IMPLEMENTATION.md) for
the tested operator commands and host templates, and the
[Codex deployment handoff](CODEX_DEPLOYMENT.md) when another agent assists.

## Reading order

1. [Launch blockers and prerequisites](#launch-blockers-and-prerequisites)
2. [Prepare the VPS](#prepare-the-vps)
3. [Local preparation](#local-preparation) and first container start
4. HTTP bootstrap, TLS, and administrator creation
5. [Launch verification](#launch-verification)
6. [Backups and recovery](PRODUCTION_RECOVERY.md)
7. [Deploy an update](#deploy-an-update) and ongoing operations

The production design uses Nginx installed on the VPS host. Nginx owns ports 80
and 443, then forwards HTTPS requests to the Rails container on
`127.0.0.1:3001`. PostgreSQL, Solid Queue, and uploaded files remain behind the
host firewall.

## Included files

| File | Purpose |
| --- | --- |
| `compose.production.yaml` | Production web, job worker, PostgreSQL, and persistent volumes |
| `.env.production.example` | Required environment variables without real secrets |
| `docker/nginx/production/lms-bootstrap.conf.example` | Temporary HTTP configuration used to request the first TLS certificate |
| `docker/nginx/production/lms.conf.example` | Final HTTPS reverse-proxy configuration |
| `docker/postgres/init-production-databases.sh` | Creates the Solid Cache and Solid Cable databases during first PostgreSQL initialization |

The development `compose.yaml` and `docker/nginx/default.conf` remain separate.
Do not use the development stack as the public production deployment.

## Architecture

```text
Internet
  |
  | HTTPS :443
  v
Host Nginx
  |
  | HTTP to 127.0.0.1:3001
  v
Rails container through Thruster :80
  |
  +--> PostgreSQL container
  +--> Solid Queue worker container
  +--> Active Storage volume
  +--> SMTP provider
  +--> OpenAI API when configured
```

Only Nginx is public. The production Compose file publishes the application on
the host loopback interface, not on every network interface. PostgreSQL has no
published host port.

Solid Queue stores its jobs in the primary database in this application. The
cache and cable databases are separate PostgreSQL databases, not separate
servers. Both application containers share `/rails/storage` for uploaded files.
Losing the VPS can therefore lose both the database and attachments unless an
off-server backup exists. Kamal is not used by this deployment path; do not
start a second proxy on ports 80/443 using Kamal alongside host Nginx.

## Launch blockers and prerequisites

The following are requirements, not claims that the repository implements them:

| Item | Current state and required action |
| --- | --- |
| Email sender | Set `MAIL_FROM` to one provider-verified email address. Both notifications and Devise use it. Startup rejects placeholders; actual provider delivery still needs verification. |
| Database privileges | Fresh volumes create a separate bootstrap administrator and non-superuser application owner. Supply different passwords. Existing volumes need a reviewed migration/restore plan; initialization does not run again. |
| Recovery | Choose recovery targets, configure the restic destination and checked-in backup timer, and complete the [restore drill](PRODUCTION_RECOVERY.md). Templates exist, but no remote storage or scheduler is installed automatically. |
| Host access | A named operator needs SSH key access, sudo, and a tested provider recovery console. |
| Public services | Supply a domain, DNS control, SMTP account, and optionally an OpenAI API key. |
| Nginx | The checked-in HTTPS template requires Nginx 1.25.1+ with the HTTP/2 module. See the compatibility instructions below. |

In the database container, `POSTGRES_USER` is the bootstrap administrator and
`LMS_APP_USER` is the application owner. In Rails/jobs, `POSTGRES_USER` is the
application owner. This intentional mapping keeps the administrator password
out of the application containers. Backups use the maintenance identity;
restores assign objects to the application owner. Custom roles/grants need
separate provisioning.

## Prepare the VPS

### Operating system and packages

Use a supported Ubuntu LTS release. Record its version, CPU architecture, disk
capacity, and the installed Docker/Nginx/PostgreSQL versions in your deployment
notes. Size the server through a staging workload test; this repository has no
measured production capacity guarantee. Leave disk headroom for image builds,
database growth, uploads, and temporary backup files.

Install Docker Engine and the Compose plugin using the current
[official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/).
Do not install Docker Desktop on the VPS. Avoid mixing distribution Docker
packages with Docker's own repository packages. Then verify:

```bash
docker version
docker compose version
sudo systemctl enable --now docker
sudo apt-get update
sudo apt-get install -y nginx certbot ufw git curl ca-certificates ruby restic
nginx -v
sudo nginx -V
sudo systemctl enable --now nginx
timedatectl status
```

Use a deployment account with explicitly granted Docker access. Docker group
membership is effectively root access; do not grant it to ordinary app users.
Verify time synchronization is active. Rails handles application dates in WIB;
host and container logs may still use UTC. Record offsets when investigating
incidents rather than changing the database's timestamp convention.

The `http2 on;` directive was introduced in Nginx 1.25.1
([Nginx reference](https://nginx.org/en/docs/http/ngx_http_v2_module.html)). If
your distribution supplies an older version, either install a supported newer
package or adapt the installed HTTPS site: remove `http2 on;` and change its
two listeners to `listen 443 ssl http2;` and `listen [::]:443 ssl http2;`.
Verify HTTP/2 module availability with `nginx -V` and always run `nginx -t`.
The examples assume `/etc/nginx/sites-available` and `sites-enabled`; packages
using `conf.d` require placing the site there instead, inside the HTTP context.

### SSH, firewall, and DNS

Before disabling password/root SSH login, test key-based login and sudo in a
second terminal and keep the existing session open. Validate any SSH changes
with `sudo sshd -t` before reloading the SSH service. Keep provider-console
access available in case a firewall or SSH change locks you out.

For a host using the standard OpenSSH port/profile:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

If SSH uses a custom port, allow that actual port before enabling UFW. Apply
the same rules at the provider firewall, restricting SSH to trusted IPs where
practical. Do not expose ports 3001 or 5432. Docker-published ports can bypass
UFW rules, so preserve the loopback binding and private database network
([Docker firewall warning](https://docs.docker.com/engine/install/ubuntu/)).

Create the domain's A record pointing to the VPS IPv4 address. Add an AAAA
record only if IPv6 routing and firewall rules also work. Check both from
outside the server before requesting a certificate. Permit outbound DNS,
HTTPS for external APIs/registry access, and the SMTP provider's submission
port. Do not run Mailpit as the production mail service.

### Checkout and deployment record

Clone the repository with a read-only deployment credential into a directory
owned by the deployment account, for example `/srv/lms`. Replace the example
repository URL before running:

```bash
git clone https://example.com/your-team/lms.git /srv/lms
cd /srv/lms
git status --short
git rev-parse HEAD
```

Use an approved release commit/tag. Store the commit, image tag/digest, database
version, deployment time, operator, and backup location in a deployment record.
Keep that record and backups outside the image build context.

## Local preparation

Copy the production environment template:

```bash
cp .env.production.example .env.production
chmod 600 .env.production
```

Replace every placeholder in `.env.production`. Keep that file outside Git. In
particular, change:

- `APP_HOST`
- `RAILS_MASTER_KEY`
- `LMS_DATABASE_PASSWORD`
- `POSTGRES_ADMIN_PASSWORD` (different from the application password)
- `MAIL_FROM` (verified with the SMTP provider)
- SMTP host and credentials
- `LMS_IMAGE` when using a container registry
- `OPENAI_API_KEY` when AI-assisted grading is enabled

`APP_HOST` must be a hostname only, without `https://`, a port, or a path.
Use the master key that matches the repository's encrypted credentials.
Generating a random replacement key alone will not decrypt existing
`config/credentials.yml.enc`. Store the matching key and encrypted credentials
in your protected recovery inventory. Never print decrypted credentials into
deployment logs or paste them into tickets.

Generate a database password with a password manager or `openssl rand -hex 32`.
Use your editor to place it in the protected environment file. Compose parses
environment-file values; single-quote literal secrets containing `$` or `#`
according to [Compose environment-file syntax](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).
Do not `source` this file into a shell. `--env-file` supplies interpolation
values; only variables listed in the Compose `environment` mapping enter the
containers. Existing exported shell variables take precedence over the file.

`POSTGRES_HOST` and `POSTGRES_PORT` are fixed to `db:5432` in production Compose;
adding those variables to the environment file does not move the database.
Changing the database password in the file also does not change an existing
PostgreSQL role's password: coordinate the SQL password rotation and container
recreation in a maintenance window.

Use `SMTP_PORT=587`, `SMTP_ENABLE_STARTTLS_AUTO=true`, `SMTP_SSL=false` for
STARTTLS, or `SMTP_PORT=465`, `SMTP_ENABLE_STARTTLS_AUTO=false`, `SMTP_SSL=true`
for implicit TLS, according to the provider. Preflight rejects contradictory or
unencrypted SMTP settings. Configure provider domain verification, SPF, DKIM,
and DMARC. Verify notifications and Devise mail using `MAIL_FROM`.

For a local production rehearsal, use a separate `.env.production` and unused
port such as `LMS_HTTP_PORT=3101` if development already occupies 3001. Adjust
the curl commands and both installed Nginx configurations to match. Do not
expect secure login cookies to work through plain localhost HTTP; full browser
testing needs HTTPS. Never connect a rehearsal stack to production data/services.

Validate the resolved Compose configuration:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  config --quiet
```

Build the production image locally:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  build
```

The production Dockerfile precompiles assets. Runtime secrets are not copied
into the image.

After building/pulling the selected image, run `bin/production check`. The
operator commands require host Ruby, but not host Rails/Bundler. They default
to this project's production env file and Compose project. The entrypoint also
checks app settings on every production start, without printing secret values.
For a release build, add `--build-arg BUILD_REVISION=<approved-commit>` to
`docker build` so backup manifests can identify the source revision.

On Apple Silicon, a normal local build produces an ARM image. Build on the VPS
or publish an image matching its architecture. For an AMD64 VPS, an example
registry build (replace the account and release tag) is:

```bash
docker buildx build --platform linux/amd64 \
  --tag ghcr.io/your-account/lms:release-tag --push .
```

This publishes an image; run it only against your own registry. Keep immutable
release tags/digests and authenticate with a read-only pull credential on the
VPS. Set `LMS_IMAGE` to that image, then use `pull web jobs` and `up -d --no-build`
instead of building on the VPS. Do not reuse a release tag for different code.

## First container start

Start PostgreSQL, Rails, and the worker:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  up -d
```

Check the services:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  ps

curl --fail http://127.0.0.1:3001/up
```

The Rails container runs `db:prepare` before starting the server. On a new
PostgreSQL volume, the initialization script creates the primary, cache, and
cable databases. Rails loads the seed file while preparing a new primary
database, which synchronizes the permission catalog. No administrator is
created unless the optional administrator variables are present. The job
container waits for the web health check before it starts.

The database initialization script only runs when PostgreSQL creates an empty
data directory. If database names change after initialization, create those
databases manually or initialize a new volume after safely exporting existing
data.

Do not run `docker compose down --volumes`, `docker volume prune`, or
`db:reset` against this stack. Those are not deployment troubleshooting steps.
The default volume names are `lms-production_postgres_data` and
`lms-production_active_storage`; changing the Compose project name selects
different volumes and can make the application appear empty.

## Install the HTTP bootstrap configuration

The final HTTPS configuration references certificate files that do not exist
yet. Install the bootstrap configuration first.

On the VPS:

```bash
sudo mkdir -p /var/www/certbot
sudo cp docker/nginx/production/lms-bootstrap.conf.example \
  /etc/nginx/sites-available/lms
sudo ln -s /etc/nginx/sites-available/lms /etc/nginx/sites-enabled/lms
```

Replace every `lms.example.com` value with the real hostname. Remove the
distribution's default Nginx site if it conflicts, then validate and reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

The bootstrap site serves the ACME challenge directory and the Rails health
endpoint. Other requests return HTTP 503 until HTTPS is ready.

## Issue the TLS certificate

After the domain's DNS record points to the VPS and ports 80 and 443 are open,
install Certbot and request the certificate through the webroot:

```bash
sudo certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --domain lms.example.com
```

Use the real hostname. Certificate issuance cannot be tested without working
public DNS and inbound HTTP access.

## Install the final HTTPS configuration

Copy `docker/nginx/production/lms.conf.example` over the bootstrap site and
replace every occurrence of `lms.example.com` with the real hostname.

```bash
sudo cp docker/nginx/production/lms.conf.example \
  /etc/nginx/sites-available/lms
sudoedit /etc/nginx/sites-available/lms
sudo nginx -t
sudo systemctl reload nginx
```

The final configuration provides:

- HTTP-to-HTTPS redirection
- TLS 1.2 and TLS 1.3
- Forwarded host, client address, scheme, and port headers
- WebSocket upgrade support for live messages and notifications
- A 100 MB request limit for supported uploads
- Extended proxy timeouts for long-running requests
- A quiet `/up` health endpoint

Install a renewal deployment hook so Nginx loads newly issued certificates.
Create `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx` using `sudoedit`
with this content:

```sh
#!/bin/sh
set -eu
/usr/sbin/nginx -t
/usr/bin/systemctl reload nginx
```

The same hook is checked in at `deploy/certbot/reload-nginx`. After reviewing
the executable paths, install it with `sudo install -o root -g root -m 755
deploy/certbot/reload-nginx /etc/letsencrypt/renewal-hooks/deploy/reload-nginx`.

Confirm those executable paths on the VPS, then set ownership/permissions and
test renewal:

```bash
sudo chown root:root /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
sudo chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
sudo systemctl enable --now certbot.timer
sudo systemctl list-timers --all certbot.timer
sudo certbot renew --dry-run --run-deploy-hooks
```

These scheduling commands assume the distribution's Certbot systemd package.
If installed another way, verify its scheduler rather than creating duplicate
timers. Check `certbot renew --help all` if the installed version lacks
`--run-deploy-hooks`; upgrade or test the hook explicitly after a dry run.
Monitor certificate expiry externally. See the
[Certbot renewal documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates).

Rails already enables HSTS through `config.force_ssl = true`; it is not
disabled pending Nginx setup. Before first public access, verify the HTTPS
domain and renewal path. `HSTS_ENABLED=true` is the default;
`HSTS_SUBDOMAINS=false` avoids forcing HTTPS on unrelated subdomains, and
preload is disabled. Do not add
a second, conflicting HSTS policy in Nginx or submit the domain for preloading
without a deliberate domain-wide decision. Use a separate hostname for testing.

## Create the first console administrator

The preferred operator command is `bin/production bootstrap-admin`. It reads
the password without echoing it and passes it only to the one-time seed command.
The equivalent manual procedure follows for environments without the helper.

Use a temporary environment passed explicitly to `docker compose exec`. Run
this in Bash; the password prompt does not echo or place the literal password
in shell history. Do not enable shell tracing (`set -x`).

```bash
(
  set -e
  read -r -p 'Console admin email: ' ADMIN_EMAIL
  read -r -p 'Console admin name: ' ADMIN_NAME
  read -r -s -p 'Initial password: ' ADMIN_PASSWORD
  printf '\n'
  export ADMIN_EMAIL ADMIN_NAME ADMIN_PASSWORD
  docker compose --env-file .env.production -f compose.production.yaml \
    exec -e ADMIN_EMAIL -e ADMIN_NAME -e ADMIN_PASSWORD web bin/rails db:seed
)
```

The subshell discards these shell variables on exit. Privileged host operators
can still inspect process environments, so only perform this on a trusted host.
The seed synchronizes RBAC and provisions the console super-administrator role.
It does not replace an existing administrator's password. Log in at
`https://your-domain/console/login`, verify access, and do not retain bootstrap
credentials in `.env.production`. Use the console UI for later administrator
management. For troubleshooting, open a Rails console with:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  exec web bin/rails console
```

## Deploy an update

The scripted path is `bin/production deploy /absolute/path/to/new-backup-dir`
after building/pulling and selecting the new image. It takes a local backup,
stops writers, waits for the new web to be healthy, synchronizes RBAC, and starts
jobs. It never automatically rolls back a database. Transfer the backup off-server
and complete the smoke tests. The manual equivalent follows.

Use a planned maintenance window. This template starts migrations during web
startup and does not provide zero-downtime releases. Notify users, especially
those with running timed quizzes; wall-clock quiz timers do not pause during
an outage. Record the previous image and commit, retain that image, and read
the release's migration notes before proceeding.

1. Build or pull the approved immutable image before stopping the old release.
   Use a new `LMS_IMAGE` tag for every release, including local builds.
2. Stop web and jobs and take the consistent backup described in
   [production recovery](PRODUCTION_RECOVERY.md). Keep them stopped after the
   backup for this update. Requests will receive a proxy error while web is
   down; use a separately tested maintenance response if required.
3. Start only web first, which runs `db:prepare`. Check migrations and health
   before starting jobs; do not let old workers run against a changing schema.
4. Synchronize RBAC, start jobs, and complete the smoke tests below.

For a source-built release, first fetch/check out the approved release and
build it (replace `release-tag` with the real reviewed tag):

```bash
git status --short
git fetch --tags
git switch --detach release-tag
docker compose --env-file .env.production -f compose.production.yaml build web
```

Do not overwrite local edits when selecting a release. For registry deployment,
set `LMS_IMAGE` to the approved tag/digest and pull instead:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  pull web jobs
```

After the backup, with the previous web and jobs containers stopped:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  up -d --no-build --no-deps web
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs --tail=100 web
curl --fail http://127.0.0.1:3001/up
```

Wait until web is healthy and inspect its logs for successful migrations. Only
then check migration status and synchronize RBAC:

```bash
docker compose --env-file .env.production -f compose.production.yaml \
  exec web bin/rails db:migrate:status
docker compose --env-file .env.production -f compose.production.yaml \
  exec web bin/rails runner 'RbacSeeder.call!'
```

When these checks succeed, start the new worker:

```bash
docker compose --env-file .env.production -f compose.production.yaml \
  up -d --no-build --no-deps jobs
```

If any step fails, keep jobs stopped and follow the
[rollback decision](PRODUCTION_RECOVERY.md#rollback-after-a-failed-release).
Do not start the new worker simply because `up -d` returned successfully.

For an environment-only change, edit the protected file, validate with
`config --quiet`, then recreate the affected containers using `up -d --no-build
--force-recreate web jobs`. A plain `restart` does not apply changed environment
variables. Database password/name changes require separate database work.

## Launch verification

Record results on staging first, then repeat after the first production launch
and significant updates. `/up` confirms application boot, not every dependency.

- [ ] HTTP redirects to HTTPS; the certificate matches the hostname and chain.
- [ ] `curl --fail https://your-domain/up` succeeds from outside the VPS.
- [ ] Ports 3001/5432 are unreachable externally, including over IPv6.
- [ ] Console and organization login/logout work without CSRF errors.
- [ ] Teacher/student permissions and organization isolation work with test accounts.
- [ ] CSS, editor controls, images, and JavaScript load without browser errors.
- [ ] Upload and download a document/audio file and a generated certificate.
- [ ] Two separate browser sessions exchange messages and update notifications live.
- [ ] A queued notification email and a password-reset email reach a real inbox,
      with the right sender and HTTPS links; inspect the provider's delivery log.
- [ ] Jobs process queued work; recurring recovery work is scheduled and failures
      are visible to an operator. Test with controlled data, not real students.
- [ ] A timed quiz can resume and expire correctly; UI/email dates show WIB.
- [ ] If enabled, OpenAI analysis completes or reports an actionable error.
- [ ] A planned container restart preserves data and uploaded files.
- [ ] Renewal test and isolated backup restore drill pass.
- [ ] All launch blockers above have an owner and are resolved before real use.

## Logs and operational checks

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  logs --tail=200 web jobs db

sudo tail -n 200 /var/log/nginx/lms-error.log
sudo systemctl status nginx
```

Monitor external HTTPS availability, certificate expiry, disk/inode usage,
memory/OOM restarts, PostgreSQL storage/connections, failed/old queued jobs, and
the age of the last successful off-server backup. A running worker process
alone does not prove that email or scheduled jobs work. Assign an alert recipient
and test an alert. Keep `RAILS_LOG_LEVEL=info` normally; logs can contain student
information, so restrict access and retention and redact before sharing.

Production Compose now sets the `local` logging driver with 20 MB files and
five files per container. Recreate containers to apply the service settings;
there is no need to replace `/etc/docker/daemon.json`. Verify
`/etc/logrotate.d/nginx` covers `/var/log/nginx/lms-*.log`. See
[Docker logging configuration](https://docs.docker.com/engine/logging/configure/).
Choose retention based on available space and your privacy requirements.

`bin/production verify` checks Rails credentials decryption, all databases,
application role privileges, worker heartbeats, and failed jobs. The checked-in
health timer runs `bin/production monitor`, which additionally checks backup
freshness. Follow the [host-template installation steps](PRE_HOSTING_IMPLEMENTATION.md#step-4-host-templates-and-encrypted-backups)
to install backup/monitoring timers and alerts; no service is installed by merely
checking out these files.

### Troubleshooting

| Symptom | Check before changing anything |
| --- | --- |
| Nginx rejects `http2` | Check version/module and use the documented compatible listener syntax. |
| TLS issuance fails | Check A/AAAA records, external port 80, ACME webroot, and conflicting default sites. |
| 502 or unhealthy web | Read web/db logs, verify port alignment, credentials, and migration status. Do not delete volumes. |
| Login/CSRF or redirect issues | Use the canonical HTTPS hostname; verify forwarded host/protocol and browser cookies. Do not disable CSRF protection. |
| Email fails | Check both sender addresses, provider verification, credentials, STARTTLS port, job failures, and outbound network access. |
| Messages do not update | Inspect the `/cable` WebSocket connection and proxy upgrade headers, cable database, and web logs. |
| Upload returns 413 | Nginx limits requests to 100 MB; check application limits too. Do not raise only one layer without resource planning. |
| AI/request times out | Inspect Rails, provider, Thruster, and Nginx limits; the Nginx timeout alone is not an end-to-end guarantee. |
| App appears empty after deployment | Check Compose project name, mounted volumes, and database names before creating anything. |
| Edits do not appear | Production code/assets are inside the image: rebuild/redeploy. Environment changes require recreation. |

Do not run the test suite or `db:test:prepare` against production credentials.
Run `bin/ci` in development/CI before approving a release. Public TLS, external
SMTP delivery, load capacity, and recovery time require real deployment tests;
documentation and local startup checks cannot certify them.
