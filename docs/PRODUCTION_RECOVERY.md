# Production backups, restore drills, and rollback

Use this with [the production deployment guide](PRODUCTION_DEPLOYMENT.md).
These are operator-run procedures for the current single-host Compose template,
not installed backup automation. Run commands in Bash from the checkout root.
Replace example paths and release names deliberately before executing anything.

The preferred scripted path is now `bin/production backup NEW_DIRECTORY`, or
`bin/production backup-to-restic` after configuring encrypted remote storage.
The helper writes `manifest.json`, `checksums.json`, and a `COMPLETE` marker;
`bin/production restore DIRECTORY` verifies those files and only permits a new
`lms-restore-NAME` project using the exact backed-up image. The manual procedure
below uses a different manifest/checksum format and must be restored manually.
Do not mix the two formats. See the
[implementation record](PRE_HOSTING_IMPLEMENTATION.md#step-3-operator-commands)
for commands and [Codex handoff](CODEX_DEPLOYMENT.md) for agent-assisted recovery.

## What must be recoverable

| Component | Why it matters |
| --- | --- |
| Primary PostgreSQL database | Users, permissions, courses, answers, grades, messages, attachment metadata, and Solid Queue jobs |
| Active Storage files | Uploaded documents/images/audio and other stored attachments; database rows alone cannot recover these |
| Cache and cable databases | Runtime state; back them up here for a same-release restore, even though they can be recreated with the matching schemas |
| Release image and commit | The application version that understands the backed-up schema |
| Secrets and configuration | Matching Rails master key/encrypted credentials, environment, database role provisioning, SMTP/API settings, Nginx and certificate-renewal configuration |

Persistent Docker volumes survive ordinary container recreation, but are not
backups. A VPS snapshot is an additional recovery option, not proof that the
database and uploads form a consistent recoverable pair.

Choose and record your recovery point objective (maximum acceptable data loss)
and recovery time objective (maximum outage). For example, daily backups alone
can lose up to a day's work; this is not a recommendation for every deployment.
If the required recovery point is shorter, plan more frequent backups or
PostgreSQL WAL archiving/point-in-time recovery and coordinated file retention.
Those facilities are not configured in this repository.

## Consistent manual backup

This baseline stops both writers for the duration of the dump and file archive.
Schedule the outage and warn students: quiz time limits continue to elapse.
If uptime requirements cannot tolerate this, design an online backup approach
before launch. Do not improvise by copying a running PostgreSQL data directory.

Preconditions:

- Web and jobs are the only application writers; stop any ad hoc Rails consoles,
  importers, external database clients, or other workers as well.
- PostgreSQL is healthy and the backup destination has sufficient free space.
- Keep backups outside the repository/build context and protect them as student
  data. They include private messages, answers, and account information.
- Retain the exact old application image before replacing it with a new tag.

Define this helper in your current Bash session. It always selects production;
do not substitute the development Compose file:

```bash
prod() {
  docker compose --env-file .env.production -f compose.production.yaml "$@"
}
prod ps
df -h
```

Create a unique, private directory, then stop the writers. The default database
names come from the container environment, not hard-coded dump arguments:

```bash
umask 077
backup_dir=$(mktemp -d /var/tmp/lms-backup.XXXXXXXX)
printf 'Backup directory: %s\n' "$backup_dir"
prod stop -t 120 jobs web
prod ps --all
```

Confirm both application containers are stopped before continuing. A worker
forced to stop can leave a job needing recovery, so record any interrupted
grading/email task and inspect it after restart. Execute the backup block:

```bash
(
  set -euo pipefail
  test -d "$backup_dir"
  prod exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "$backup_dir/primary.dump"
  prod exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_CACHE_DB" -Fc' \
    > "$backup_dir/cache.dump"
  prod exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_CABLE_DB" -Fc' \
    > "$backup_dir/cable.dump"
  prod run --rm --no-deps -T --entrypoint tar web \
    -czf - -C /rails/storage . > "$backup_dir/storage.tar.gz"
  git rev-parse HEAD > "$backup_dir/checkout-commit.txt"
  docker inspect --format '{{.Image}}' "$(prod ps --all -q web)" \
    > "$backup_dir/web-image-id.txt"
  prod exec -T db postgres --version > "$backup_dir/postgres-version.txt"
  prod exec -T db pg_restore --list < "$backup_dir/primary.dump" > /dev/null
  prod exec -T db pg_restore --list < "$backup_dir/cache.dump" > /dev/null
  prod exec -T db pg_restore --list < "$backup_dir/cable.dump" > /dev/null
  tar -tzf "$backup_dir/storage.tar.gz" > /dev/null
  (
    cd "$backup_dir"
    sha256sum primary.dump cache.dump cable.dump storage.tar.gz \
      checkout-commit.txt web-image-id.txt postgres-version.txt > SHA256SUMS
  )
)
```

Check the block's exit status immediately. If it fails, label the backup
incomplete; do not use partial dump files. Investigate the error and decide
whether to retry or resume service. This procedure deliberately leaves web/jobs
stopped on failure rather than silently resuming a failed maintenance operation.
Archive listing/checksums detect some corruption, not logical correctness:
only the restore drill below verifies usability.

Store the image tag/digest, database names/user, timestamp and offset, operator,
and archive directory in the deployment record. An image ID alone does not
preserve the image: keep it in your registry or export the retained image with
`docker image save`. `checkout-commit.txt` records the checkout, which may
already contain the next release. Record the currently running release's commit
and configuration separately from the previous deployment record; that is the
version to use for restoring this pre-update backup. Keep protected copies of
the pre-update `.env.production`, the matching
Rails credentials/key, and host configuration in a secrets vault or separately
encrypted recovery bundle. Do not print their values into the record.

For a backup-only maintenance window, resume the existing containers:

```bash
prod start web
prod ps
curl --fail http://127.0.0.1:3001/up
```

Wait for web to become healthy, then run `prod start jobs` and verify processing.
For an update, leave both stopped and return to the deployment guide instead.

### Off-server retention and scheduling

Encrypt the completed backup before transfer using your organization's backup
tool and key-management policy. Upload it to a separately secured off-server
destination. Keep the decryption key recoverable outside this VPS; test access
from a second machine. Verify remote integrity and do a restore from the remote
copy, not only the local staging directory. Never describe a local `/var/tmp`
archive as disaster recovery.

Before launch, an operator must install and test the checked-in backup service
and timer (see `deploy/systemd`). The helper locks overlapping operations,
resumes the previous services after a backup failure when possible, and marks
successful restic transfers. Operators must still check disk capacity, configure
the destination and failure-alert receiver, and verify remote recovery.
Decide retention and deletion rules explicitly. Do not remove the previous
known-good backup because a new upload merely started. Exclude secrets from
logs. Clean up each explicitly identified staging directory only after verified
transfer and according to retention policy; do not use broad volume pruning.

For unattended jobs, do not blindly schedule the interactive steps above.
Review the scripted failure handling, service-resumption policy, and outage
notifications first. Check the age of the latest successful remote backup with
an independent monitor, so a stopped scheduler produces an alert too.

## Restore drill on an isolated host

Never start a restore by dropping the live database. Use a separate host or
isolated Docker environment and fresh volumes. The restored database contains
queued jobs: starting workers against real SMTP/API services may resend mail
or repeat external actions.

1. Retrieve a trusted, decrypted backup from off-server storage. Verify
   `sha256sum -c SHA256SUMS` from its directory. Only restore trusted dumps;
   PostgreSQL restores execute SQL from the archive.
2. Check out the recorded application commit and obtain the matching image.
   Use the same PostgreSQL major version as the backup (currently 18). Do not
   change the production major-version tag as an upgrade strategy.
3. Copy the environment securely to `.env.restore`, mode 600. Preserve the
   credentials key and database identity needed by the data, but replace SMTP
   credentials/address with an isolated mail sink, clear the Gemini key, and
   use a test hostname. Keep required SMTP variables nonempty. Block outbound
   delivery/API traffic at the rehearsal network boundary as a second guard.
4. Keep jobs stopped. Use a distinct project name and port. On the isolated
   host, verify that project/its volumes do not already contain valuable data.

Define a separate helper. `LMS_HTTP_PORT` explicitly overrides the environment
file for this rehearsal; production Nginx must not point to it:

```bash
restore_stack() {
  LMS_HTTP_PORT=3101 docker compose -p lms-restore \
    --env-file .env.restore -f compose.production.yaml "$@"
}
restore_stack config --quiet
restore_stack ps --all
docker volume ls --filter label=com.docker.compose.project=lms-restore
```

If the project or its volumes already exist, stop and choose a new, unique
restore project name. Do not delete them to make these commands work. With a
fresh project, start only PostgreSQL and wait until it is healthy:

```bash
restore_stack up -d db
restore_stack ps
restore_stack logs --tail=100 db
```

The initializer creates empty primary/cache/cable databases. Do not start Rails
or run `db:prepare` before importing, as that would populate the empty databases.
Set `backup_dir` to the actual verified archive directory, then restore:

```bash
backup_dir=/absolute/path/to/verified-backup
(
  set -euo pipefail
  test -f "$backup_dir/primary.dump"
  restore_stack exec -T db sh -c \
    'pg_restore --exit-on-error --single-transaction --no-owner --no-acl -U "$LMS_APP_USER" -d "$POSTGRES_DB"' \
    < "$backup_dir/primary.dump"
  restore_stack exec -T db sh -c \
    'pg_restore --exit-on-error --single-transaction --no-owner --no-acl -U "$LMS_APP_USER" -d "$POSTGRES_CACHE_DB"' \
    < "$backup_dir/cache.dump"
  restore_stack exec -T db sh -c \
    'pg_restore --exit-on-error --single-transaction --no-owner --no-acl -U "$LMS_APP_USER" -d "$POSTGRES_CABLE_DB"' \
    < "$backup_dir/cable.dump"
  restore_stack run --rm --no-deps -T --user 0:0 --entrypoint tar web \
    -xzf - -C /rails/storage < "$backup_dir/storage.tar.gz"
  restore_stack run --rm --no-deps -T --user 0:0 --entrypoint chown web \
    -R 1000:1000 /rails/storage
)
```

The archive extraction targets only the new project's storage volume. UID/GID
1000 match the checked-in Dockerfile. These dumps omit ownership/grants during
restore so the non-superuser application owner (`LMS_APP_USER` inside the DB
container) owns the restored objects. They do not back up cluster-wide roles or
custom grants. The fresh-volume initializer provisions the standard accounts;
provision and verify any additional roles explicitly.

If import fails, keep the stack isolated and inspect the error; do not continue
on top of a partial restore. Use another fresh project for a repeat drill.
After successful import, start the matching web image only:

```bash
restore_stack up -d --no-build --no-deps web
restore_stack ps
restore_stack logs --tail=100 web
curl --fail http://127.0.0.1:3101/up
restore_stack exec web bin/rails db:migrate:status
```

Use an isolated HTTPS proxy/test hostname for authenticated browser checks.
Confirm account counts against your recorded baseline, roles, representative
courses, submitted/reviewed attempts, certificates, and downloaded attachments.
Only after outbound traffic is contained, start jobs with
`restore_stack up -d --no-build --no-deps jobs` and inspect pending/failed jobs.
Restored jobs can refer to work already sent before the outage; decide whether
they should run before enabling production integrations. Do not blanket-delete
queue tables as a recovery shortcut.

Record restore duration, backup age, errors, sample checks, and operator signoff.
Stop rehearsal containers when finished; retain or remove their explicitly
identified volumes according to your data-handling policy. No production volume
should be involved. Repeat drills after schema/storage changes and on a planned
schedule.

## Rollback after a failed release

Decide based on database compatibility, not just whether an old image exists:

- If no schema/data migration ran, or the old release is proven compatible
  with the new schema, stop web/jobs, select the retained previous image in
  `LMS_IMAGE`, and recreate web first using `up -d --no-build --no-deps web`.
  Check health before recreating jobs. Use the same production project/volumes.
- If compatibility is unknown or migrations were destructive, keep writers
  stopped. Restore the pre-release database and file snapshot together on a
  replacement stack using the procedure above and the old image. A code-only
  rollback cannot recover dropped columns or transformed data.
- Do not run `db:rollback` blindly. Migrations may be irreversible or may lose
  data even when a `down` method exists.

For source deployments, restore the matching checked-out commit/configuration
as well as the image selection. Do not rebuild an old mutable image tag and
assume it is identical to the retained release. Avoid `--build` in an image
rollback, which could rebuild from the wrong checkout.

Restoring a snapshot discards writes after that snapshot, including messages,
answers, and grades. Get approval for that loss or plan a reconciliation before
cutover. Keep the old stack/volumes intact for investigation, isolated from new
writes. Verify the replacement with outbound effects contained, then stop the
old writers, point Nginx to the replacement's loopback port, validate/reload
Nginx, and run the launch checks. Re-enable production SMTP/API access and jobs
only after resolving queued external side effects. Document the new stack name,
port, configuration paths, and backup schedule so later deployments target it.

## Reference behavior

PostgreSQL [pg_dump](https://www.postgresql.org/docs/18/app-pgdump.html) provides
custom-format archives, and [pg_restore](https://www.postgresql.org/docs/18/app-pgrestore.html)
supports archive inspection, ownership/grant handling, and stopping on errors.
The examples use clients from the database container to match the server major
version. Validate the full procedure on your actual deployment before relying
on it during an incident.
