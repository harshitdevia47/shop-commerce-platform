#!/bin/sh
# Daily backup: all databases, public + private photos, Redis (event streams).
# Keeps BACKUP_KEEP_DAYS locally and, when RCLONE_REMOTE is set (e.g. "b2:qc-backups"), copies
# each run off the server with rclone. Run from cron as the deploy user:
#   15 2 * * * cd ~/qc/deploy && ./scripts/backup.sh >> ~/backups/backup.log 2>&1
set -eu

cd "$(dirname "$0")/.."
PROJECT="${COMPOSE_PROJECT_NAME:-qc}"
DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP="${BACKUP_KEEP_DAYS:-14}"
STAMP="$(date +%F-%H%M)"
OUT="$DIR/$STAMP"
mkdir -p "$OUT"

set -a; . ./.env; set +a

echo "[$(date "+%Y-%m-%dT%H:%M:%S%z")] backup $STAMP -> $OUT"

# Postgres: every service database in one consistent-per-database dump.
docker compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" --clean --if-exists | gzip -9 > "$OUT/postgres.sql.gz"

# Photos (volumes are read through a throwaway container; no service downtime).
for volume in media media_private; do
  docker run --rm -v "${PROJECT}_${volume}:/data:ro" -v "$OUT:/out" alpine:3.22 \
    tar czf "/out/${volume}.tgz" -C /data .
done

# Redis: undelivered events survive a server loss.
docker compose exec -T redis redis-cli SAVE > /dev/null
docker run --rm -v "${PROJECT}_redisdata:/data:ro" -v "$OUT:/out" alpine:3.22 cp /data/dump.rdb /out/redis.rdb 2>/dev/null || true

# Sanity: a dump smaller than 1 KB means something is wrong.
SIZE=$(wc -c < "$OUT/postgres.sql.gz")
if [ "$SIZE" -lt 1024 ]; then
  echo "ERROR: postgres dump is only $SIZE bytes" >&2
  exit 1
fi
( cd "$OUT" && sha256sum ./* > SHA256SUMS )

if [ -n "${RCLONE_REMOTE:-}" ]; then
  rclone copy "$OUT" "$RCLONE_REMOTE/$STAMP" --transfers 2
  echo "copied off-site to $RCLONE_REMOTE/$STAMP"
fi

find "$DIR" -mindepth 1 -maxdepth 1 -type d -mtime "+$KEEP" -exec rm -rf {} +
echo "[$(date "+%Y-%m-%dT%H:%M:%S%z")] done ($(du -sh "$OUT" | cut -f1))"
