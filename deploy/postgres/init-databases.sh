#!/bin/sh
# Creates one database per service (plus a _test twin) on first container start.
# Runs only when the Postgres data volume is empty.
set -eu

SERVICES="tenant identity catalog order payment delivery media notification reporting"

for svc in $SERVICES; do
  for db in "qc_${svc}" "qc_${svc}_test"; do
    echo "Creating database ${db}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
      -c "CREATE DATABASE \"${db}\";"
  done
done
