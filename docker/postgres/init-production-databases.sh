#!/bin/sh
set -eu

for identifier in "$POSTGRES_USER" "$LMS_APP_USER" "$POSTGRES_DB" "$POSTGRES_CACHE_DB" "$POSTGRES_CABLE_DB"; do
  case "$identifier" in
    ""|*[!a-z0-9_]*|[0-9]*) echo "Database identifiers must use lowercase letters, digits, and underscores." >&2; exit 1 ;;
  esac
  [ "${#identifier}" -le 63 ] || exit 1
done
[ "$POSTGRES_USER" != "$LMS_APP_USER" ] || { echo "Database administrator and application roles must differ." >&2; exit 1; }
[ "$POSTGRES_PASSWORD" != "$LMS_DATABASE_PASSWORD" ] || { echo "Database administrator and application passwords must differ." >&2; exit 1; }
[ "${#POSTGRES_PASSWORD}" -ge 24 ] && [ "${#LMS_DATABASE_PASSWORD}" -ge 24 ] || { echo "Database passwords must be at least 24 characters." >&2; exit 1; }
[ "$POSTGRES_DB" != "$POSTGRES_CACHE_DB" ] && [ "$POSTGRES_DB" != "$POSTGRES_CABLE_DB" ] && [ "$POSTGRES_CACHE_DB" != "$POSTGRES_CABLE_DB" ] || exit 1
for database in "$POSTGRES_DB" "$POSTGRES_CACHE_DB" "$POSTGRES_CABLE_DB"; do
  case "$database" in postgres|template0|template1) echo "Application databases must not use system database names." >&2; exit 1 ;; esac
done

# Only the official image's empty-volume initialization invokes this script.
psql -X --set ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
\getenv app_user LMS_APP_USER
\getenv app_password LMS_DATABASE_PASSWORD
\getenv primary_db POSTGRES_DB
\getenv cache_db POSTGRES_CACHE_DB
\getenv cable_db POSTGRES_CABLE_DB
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER DATABASE :"primary_db" OWNER TO :"app_user";
CREATE DATABASE :"cache_db" OWNER :"app_user";
CREATE DATABASE :"cable_db" OWNER :"app_user";
REVOKE ALL ON DATABASE :"primary_db" FROM PUBLIC;
REVOKE ALL ON DATABASE :"cache_db" FROM PUBLIC;
REVOKE ALL ON DATABASE :"cable_db" FROM PUBLIC;
SQL
