# Production deployment with Nginx and Docker Compose

This runbook describes the production boilerplate included in the repository.
It can be prepared and tested locally before a VPS, domain, SMTP account, or TLS
certificate exists.

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
  +--> Gemini API when configured
```

Only Nginx is public. The production Compose file publishes the application on
the host loopback interface, not on every network interface. PostgreSQL has no
published host port.

## Local preparation

Copy the production environment template:

```bash
cp .env.production.example .env.production
```

Replace every placeholder in `.env.production`. Keep that file outside Git. In
particular, change:

- `APP_HOST`
- `RAILS_MASTER_KEY`
- `LMS_DATABASE_PASSWORD`
- SMTP host and credentials
- `LMS_IMAGE` when using a container registry
- `GEMINI_API_KEY` when AI-assisted grading is enabled

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

Test certificate renewal after installation:

```bash
sudo certbot renew --dry-run
```

Do not enable HTTP Strict Transport Security until HTTPS and certificate
renewal have been verified. A mistaken HSTS configuration can make recovery
harder because browsers remember the HTTPS requirement.

## Create the first console administrator

The default production environment does not retain administrator bootstrap
credentials. Use a controlled one-time seed after setting strong `ADMIN_EMAIL`,
`ADMIN_PASSWORD`, and `ADMIN_NAME` values in the command environment.

The seed also synchronizes the RBAC permission catalog. Do not leave the
bootstrap password in `.env.production` after the administrator exists.

Alternatively, open a production Rails console and create the administrator and
super-administrator role explicitly:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  exec web bin/rails console
```

## Deploy an update

For a locally built image:

```bash
git pull --ff-only
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  up -d --build
```

For a registry image, set `LMS_IMAGE` to an immutable tag, pull it, and replace
the application containers:

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  pull web jobs

docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  up -d web jobs
```

Check `/up`, the container logs, login, uploads, live messaging, email delivery,
and background jobs after every deployment.

## Logs and operational checks

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yaml \
  logs --tail=200 web jobs db

sudo tail -n 200 /var/log/nginx/lms-error.log
sudo systemctl status nginx
```

The remaining VPS work includes firewall configuration, SSH hardening, DNS,
certificate issuance, SMTP verification, off-server backups, monitoring, and
restore testing.
