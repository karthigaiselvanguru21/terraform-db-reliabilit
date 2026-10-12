#!/usr/bin/env bash
set -euo pipefail

# Run from repository root; Compose service defaults to "db".
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-${POSTGRES_USER:-app}}"
DB_NAME="${DB_NAME:-${POSTGRES_DB:-bookings}}"
BACKUP_DIR="${BACKUP_DIR:-backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

if [[ -n "${BACKUP_FILE:-}" ]]; then
  TARGET_BACKUP="$BACKUP_FILE"
  mkdir -p "$(dirname "$TARGET_BACKUP")"
else
  mkdir -p "$BACKUP_DIR"
  TARGET_BACKUP="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"
fi

TMP_BACKUP="${TARGET_BACKUP}.tmp"
rm -f "$TMP_BACKUP"

echo "Creating backup for database '${DB_NAME}' from service '${DB_SERVICE}'..."

# Trap to clean up temporary file on failure
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 && -f "$TMP_BACKUP" ]]; then
    echo "Backup failed. Cleaning up incomplete temporary file..." >&2
    rm -f "$TMP_BACKUP"
  fi
  exit $exit_code
}
trap cleanup EXIT ERR

docker compose exec -T "$DB_SERVICE" pg_dump \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --format=custom \
  --no-owner \
  --no-acl > "$TMP_BACKUP"

if [[ ! -s "$TMP_BACKUP" ]]; then
  echo "Error: Backup file was not created or is empty." >&2
  rm -f "$TMP_BACKUP"
  exit 1
fi

mv "$TMP_BACKUP" "$TARGET_BACKUP"
echo "Backup created successfully: $TARGET_BACKUP ($(wc -c < "$TARGET_BACKUP" | tr -d ' ') bytes)"
