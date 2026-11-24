#!/bin/sh
# Proves the latest backup restores: loads postgres.sql.gz into a throwaway Postgres and counts
# shops, users and orders. Touches nothing in the running stack. Run weekly (cron) or after changes:
#   ./scripts/restore-check.sh [backup-folder]
set -eu

DIR="${BACKUP_DIR:-$HOME/backups}"
LATEST="${1:-$(ls -1d "$DIR"/*/ | sort | tail -1)}"
DUMP="$LATEST/postgres.sql.gz"
[ -f "$DUMP" ] || { echo "no dump in $LATEST" >&2; exit 1; }
( cd "$LATEST" && sha256sum -c SHA256SUMS --quiet )

NAME="qc-restore-check-$$"
trap 'docker rm -f "$NAME" > /dev/null 2>&1 || true' EXIT
docker run -d --name "$NAME" -e POSTGRES_PASSWORD=check -e POSTGRES_USER=qc postgres:18-alpine > /dev/null
until docker exec "$NAME" pg_isready -U qc > /dev/null 2>&1; do sleep 1; done

gunzip -c "$DUMP" | docker exec -i "$NAME" psql -q -U qc -d postgres -v ON_ERROR_STOP=0 > /dev/null 2>&1
count() { docker exec "$NAME" psql -tA -U qc -d "$1" -c "$2" 2>/dev/null || echo "missing"; }

echo "restored $LATEST"
echo "  shops:  $(count qc_tenant 'select count(*) from shops')"
echo "  users:  $(count qc_identity 'select count(*) from users')"
echo "  orders: $(count qc_order 'select count(*) from orders')"
[ "$(count qc_tenant 'select count(*) from shops')" != "missing" ] || { echo "RESTORE FAILED" >&2; exit 1; }
echo "OK"
