#!/bin/sh
set -eu

validate_identifier() {
  case "$1" in
    ""|*[!a-zA-Z0-9_]*)
      echo "Invalid PostgreSQL identifier: $1" >&2
      exit 1
      ;;
  esac
}

create_database_if_missing() {
  database_name="$1"
  validate_identifier "$database_name"
  validate_identifier "$POSTGRES_USER"

  if [ "$(psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --tuples-only --no-align --command "SELECT 1 FROM pg_database WHERE datname = '$database_name'")" = "1" ]; then
    echo "Database $database_name already exists."
    return
  fi

  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    --command "CREATE DATABASE \"$database_name\" OWNER \"$POSTGRES_USER\""
}

create_database_if_missing "${POSTGRES_CACHE_DB:-lms_production_cache}"
create_database_if_missing "${POSTGRES_CABLE_DB:-lms_production_cable}"
