#!/usr/bin/env sh
# Applies every migration to a throwaway Postgres and runs the security tests.
# Usage (from the repo root, Docker running): sh supabase/tests/run.sh
set -e
cd "$(dirname "$0")/.."

container=barberflow-pg-test
if ! docker inspect "$container" >/dev/null 2>&1; then
  docker run -d --name "$container" -e POSTGRES_PASSWORD=test postgres:17 -c wal_level=logical >/dev/null
fi
docker start "$container" >/dev/null
until docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done

psql() { docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

psql -c 'drop database if exists barberflow_test' -c 'create database barberflow_test'
for f in tests/supabase_stub.sql migrations/*.sql tests/helpers.sql tests/*_test.sql; do
  echo "== $f"
  psql -d barberflow_test < "$f"
done
