#!/usr/bin/env bash
# Applies database/migrations/*.sql in filename order, once each.
# Usage: DATABASE_URL=postgres://user:pass@host:5432/db ./database/run-migrations.sh
# Each migration inserts its own row into schema_migrations inside its transaction,
# so a failed migration leaves no partial state and no version record.
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/migrations"

psql_run() { psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q "$@"; }

psql_run -c "CREATE TABLE IF NOT EXISTS schema_migrations (
  version     text PRIMARY KEY,
  description text NOT NULL,
  applied_at  timestamptz NOT NULL DEFAULT now()
);"

for file in "$DIR"/*.sql; do
  version="$(basename "$file" | cut -d_ -f1)"
  applied="$(psql_run -t -A -c "SELECT 1 FROM schema_migrations WHERE version = '$version'")"
  if [ "$applied" = "1" ]; then
    echo "skip   $version (already applied)"
    continue
  fi
  echo "apply  $version  $(basename "$file")"
  psql_run -f "$file"
done
echo "migrations up to date"
