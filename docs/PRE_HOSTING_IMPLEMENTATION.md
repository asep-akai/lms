# Pre-hosting implementation record

This records the local preparation work. Nothing here provisions a VPS, publishes
an image, registers a domain, or sends real email.

## Step 1: production settings

Both application notifications and Devise use `MAIL_FROM`. Production startup
runs `lib/production_configuration.rb` before Rails: missing/placeholder values,
malformed host/key/email/database settings, invalid pool sizes, and contradictory
SMTP TLS options stop startup without printing secrets. This validates shape,
not whether a provider accepts the credentials.

Use port 587 with `SMTP_ENABLE_STARTTLS_AUTO=true`, `SMTP_SSL=false`, or port
465 with `SMTP_ENABLE_STARTTLS_AUTO=false`, `SMTP_SSL=true`, as required by your
provider. HSTS defaults to enabled for this hostname only; subdomain coverage
and preload are not silently enabled. `HSTS_SUBDOMAINS=true` is an explicit
domain-owner decision. HTTPS and secure cookies remain enabled regardless.

The production environment example remains intentionally non-runnable until
operators replace its placeholders. Development/test retain local sender defaults.

Verification results and the remaining hosting checklist are recorded below as
each step is tested.

## Step 2: database identities and bounded logs

The database container receives `POSTGRES_ADMIN_USER`/`POSTGRES_ADMIN_PASSWORD`.
Rails and jobs receive only `POSTGRES_USER`/`LMS_DATABASE_PASSWORD`. On a fresh
volume, the initializer creates the application role without superuser,
role-creation, database-creation, replication, or RLS-bypass privileges. It owns
the three pre-created databases so it can run Rails migrations. Public database
access is revoked. The TCP health probe waits for the permanent PostgreSQL
server, not the temporary initialization socket.

This is database-level privilege reduction, not row-level tenant security;
organization isolation still relies on application policies/scopes. The owner
can migrate its own schemas. Separating migration and runtime accounts further
would be a separate hardening step.

Existing volumes are not converted automatically. Keep the previous deployment
configuration and credentials if one exists, and migrate on a tested maintenance
plan or restore into a new stack. Changing environment variables alone does not
rename roles or transfer ownership. Do not delete a volume to apply this change.

All production services use Docker's rotating `local` logger (20 MB per file,
five files per container). Container recreation applies these service-level
settings without editing the host's Docker daemon configuration.

## Step 3: operator commands

`bin/production` uses host Ruby's standard library (no host Bundler install).
Install `ruby` alongside Docker on the future VPS. It defaults to `.env.production`
and project `lms-production`. Overrides are `LMS_ENV_FILE` and `LMS_PROJECT`;
development's project name is explicitly rejected. The env file must be mode 600.

```bash
bin/production check
bin/production status
bin/production bootstrap-admin
bin/production verify
bin/production backup /var/backups/lms/manual-20261002
bin/production deploy /var/backups/lms/pre-release-20261002
```

Use unique backup destinations with existing parent directories outside the
checkout. `check` validates settings and inspects the selected local image;
build/pull it first. `verify` checks credentials decryption, database access,
application role privileges, worker heartbeats, and failed jobs. It does not
send mail or call OpenAI. `bootstrap-admin` reads secrets interactively.

Backup stops web/jobs, dumps all databases, archives storage, writes checksums
and running-image metadata, and resumes the services that were running. It
attempts to resume them on backup failure too. An unsuccessful resume exits
nonzero for operator attention. No archive or volume is automatically deleted.
Before pausing services it checks staging free space against
`LMS_BACKUP_MIN_FREE_MB` (default 1024). This is a floor, not a backup-size
estimate; increase it to cover your actual database/uploads and monitor growth.
`deploy` takes a backup, leaves writers stopped, starts the already-built new
web image and migrations, synchronizes RBAC, then starts jobs. Failed release
startup leaves jobs stopped; there is no automatic schema rollback.

Changing the selected image in `.env.production` does not change the running
container until deployment. The backup manifest records that running image,
not the selected future image. Build with `--build-arg BUILD_REVISION=<commit>`
to retain a revision label; otherwise the label explicitly reads `unknown`.

Restore requires a new `lms-restore-NAME` project with no containers or volumes,
a complete backup with matching checksums, and `LMS_RESTORE_ISOLATED=yes`.
It leaves web/jobs stopped so restored jobs cannot send mail without review:

```bash
LMS_PROJECT=lms-restore-drill LMS_ENV_FILE=.env.restore \
  LMS_RESTORE_ISOLATED=yes bin/production restore /var/backups/lms/manual-20261002
```

Before acknowledging isolation, select the backed-up image, a separate loopback
port/test hostname, and block real SMTP/API delivery. Only restore trusted
archives. The script refuses existing projects; use the recovery guide for
the later verification/cutover rather than overwriting production.

## Step 4: host templates and encrypted backups

`deploy/certbot/reload-nginx` checks Nginx syntax before reloading it following
successful certificate renewal. Install it only on the future VPS using the
deployment guide. It is not run during development.

`deploy/systemd` contains backup and health timers plus a failure-alert service.
The example backup window is 03:30 WIB and causes downtime while taking the
consistent snapshot. Review that window with the school before enabling it.
`Persistent=true` catches up missed backups after reboot, which can also cause
an unexpected maintenance window; disable it if your availability policy requires
manual rescheduling instead. Nothing enables these timers automatically.

On the future Ubuntu VPS:

1. Create the `lmsdeploy` service account, grant the deliberately root-equivalent
   Docker access, and place the checkout at `/srv/lms`. If your account/path
   differs, edit the unit templates consistently.
2. Install `ruby` and `restic`. Create `/etc/lms`, `/var/lib/lms-backups`, and
   `/var/cache/lms-backup`; restrict the first two to the deployment operator
   and give the service account the access needed for its files. Do not store
   backup archives inside `/srv/lms`.
3. Copy `deploy/backup.env.example` to `/etc/lms/backup.env` (mode 600), supply
   the off-server restic repository/backend credentials, and place its password
   in `/etc/lms/restic-password` (mode 600, readable by `lmsdeploy`). Retain that
   password separately in your recovery vault. Initialize the chosen repository
   once with `restic init`, using those credentials, then verify access.
4. Install the unit files into `/etc/systemd/system/`, run
   `sudo systemd-analyze verify /etc/systemd/system/lms-*.service /etc/systemd/system/lms-*.timer`,
   and `sudo systemctl daemon-reload`. Test a manual backup before enabling timers.
5. Configure `LMS_ALERT_URL` with an HTTPS endpoint accepting JSON
   `{ "service": "...", "status": "failed" }`. Without a configured receiver,
   alerts are journal-only and the alert command exits nonzero. Test delivery;
   the application SMTP queue is deliberately not used to report its own failure.
6. Run `sudo systemctl start lms-backup.service`, inspect its journal, retrieve
   and restore the remote snapshot, then enable the timers with
   `sudo systemctl enable --now lms-backup.timer lms-health.timer`.

`backup-to-restic` checks repository access before pausing the app, resumes the
app before uploading, and records a freshness marker only after restic succeeds.
Failures leave the local archive for recovery and fail the service. Configure
restic retention separately after approving recovery targets; this tooling never
prunes snapshots or local archives automatically. Monitor disk space and clean
up verified staging archives deliberately. Restic encrypts its repository;
the local staging archives remain plaintext, protected by directory permissions.

The health timer checks database privileges/connectivity, failed jobs, worker
heartbeats, and the last successful upload (26-hour threshold by default).
Use an independent external service for HTTPS uptime, certificate expiry, and
host-down alerts; a timer on a dead VPS cannot notify anyone.

The manual GitHub workflow `Production image rehearsal` builds the production
image for the runner's AMD64 platform and checks that missing settings are
rejected. It neither publishes to a registry nor deploys a server. Run normal
CI as well before approving a release.

## Step 5: agent handoff and verification

[CODEX_DEPLOYMENT.md](CODEX_DEPLOYMENT.md) gives other Codex agents a staged
handoff: establish the approved target, inventory it read-only, prepare locally,
deploy only with authority, verify the release, and stop before destructive
recovery or unapproved public changes. It includes a secret-safe deployment
record format and separate guidance for existing installations.

The repository's latest-version Brakeman gate required updating the scanner
from 8.0.6 to 8.1.0; no other gem versions changed. A calendar test now fixes
its reference date so its Today-link expectation does not depend on the month
in which CI runs. Browser workflow failures are treated as launch gates, not
hidden by the new deployment tools.

The updated scanner flagged notification URL validation. Paths now require a
fully anchored application-relative URL, rejecting external/protocol-relative
destinations, backslashes, and line breaks. A model regression test covers these
inputs. Deployment verification allows up to 30 seconds for worker registration
instead of reporting an immediate false failure after a successful start.
The helper checks the running jobs container's hostname, so an old worker's
recent database heartbeat cannot make a stopped/replaced worker appear healthy.

## Local verification record

Verified on 2 October 2026 using isolated Docker projects, fake provider settings,
and a synthetic attachment (not student data):

- Production image build and asset compilation on ARM64.
- Rejection of missing production settings without printing secret values.
- Absence of local env files and Rails master key from the built image.
- Fresh PostgreSQL initialization; primary/cache/cable connectivity; application
  role without superuser, createdb, createrole, replication, or RLS bypass.
- Live worker registration and zero failed jobs in the rehearsal stack.
- Consistent database/file backup, checksums, and archive readability.
- Fresh-project restore with matching attachment bytes and application-owned
  restored tables; rejection of a second restore into the same project.
- Maintenance-window deployment with a pre-release backup, healthy web startup,
  RBAC synchronization, and current-worker readiness verification.
- Compose validation, shell syntax, documentation links, and `git diff --check`.
- Final `bin/ci`: 261 Rails tests / 2,207 assertions and 31 browser tests /
  270 assertions passed; Ruby style, gem/importmap audits, Brakeman (zero
  warnings), and seed checks passed.

The temporary rehearsal/restore containers and their four synthetic-data
volumes were removed after verification. Local test backup archives were retained;
the development web, database, and Nginx containers remained running and healthy.

Host systemd installation, real TLS issuance/renewal, live SMTP delivery, alert
webhook delivery, remote restic upload/retrieval, and production capacity have
not been exercised. The templates are not evidence of those external checks.
The manual AMD64 GitHub build workflow has been added but has not been dispatched.

## Required before public launch

- [ ] Choose the VPS/domain, deployment account, and approved release/image.
- [ ] Supply protected real secrets, a verified sender, and provider DNS records.
- [ ] Configure/test Nginx HTTPS, renewal hook, SSH/firewall, and external uptime
      and certificate-expiry monitoring.
- [ ] Choose backup window, retention, recovery targets, and encrypted off-server
      destination; install timers and verify failure alerts plus remote restores.
- [ ] Complete browser, mail, AI-provider (if enabled), restart, and capacity
      smoke tests on the actual host before enrolling real users.

All code/configuration changes above are local preparation. No VPS, DNS record,
registry publication, live email, or external backup repository was created.
