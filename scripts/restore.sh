#!/usr/bin/env bash
set -euo pipefail

DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-${POSTGRES_USER:-app}}"
SOURCE_DB="${SOURCE_DB:-${POSTGRES_DB:-bookings}}"
RESTORE_DB="${RESTORE_DB:-bookings_restore}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

if [[ -n "${BACKUP_FILE:-}" ]]; then
  dump="$BACKUP_FILE"
else
  # Find newest non-empty dump file matching pattern
  dump="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${SOURCE_DB}_*.dump" -size +0c -print | sort | tail -n 1)"
fi

if [[ -z "${dump:-}" || ! -f "$dump" || ! -s "$dump" ]]; then
  echo "Error: No valid, non-empty backup file found. Run ./scripts/backup.sh first or set BACKUP_FILE." >&2
  exit 1
fi

echo "Selected backup for restore: $dump ($(wc -c < "$dump" | tr -d ' ') bytes)"
echo "Target restore database: '$RESTORE_DB' on service '$DB_SERVICE'"

# Terminate existing connections and recreate target database for a clean test
docker compose exec -T "$DB_SERVICE" psql -v ON_ERROR_STOP=1 \
  --username="$DB_USER" --dbname=postgres \
  --set=restore_db="$RESTORE_DB" --set=db_owner="$DB_USER" <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = :'restore_db' AND pid <> pg_backend_pid();
SELECT format('DROP DATABASE IF EXISTS %I', :'restore_db') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'restore_db', :'db_owner') \gexec
SQL

echo "Restoring database dump into '$RESTORE_DB'..."
docker compose exec -T "$DB_SERVICE" pg_restore \
  --username="$DB_USER" \
  --dbname="$RESTORE_DB" \
  --no-owner \
  --no-acl \
  --exit-on-error < "$dump"

echo "Restore completed successfully."
echo "Verifying row counts between source ('$SOURCE_DB') and target ('$RESTORE_DB')..."

SOURCE_BOOKINGS=$(docker compose exec -T "$DB_SERVICE" psql -t -A -v ON_ERROR_STOP=1 --username="$DB_USER" --dbname="$SOURCE_DB" -c "SELECT COUNT(*) FROM hotel_bookings;")
RESTORE_BOOKINGS=$(docker compose exec -T "$DB_SERVICE" psql -t -A -v ON_ERROR_STOP=1 --username="$DB_USER" --dbname="$RESTORE_DB" -c "SELECT COUNT(*) FROM hotel_bookings;")

SOURCE_EVENTS=$(docker compose exec -T "$DB_SERVICE" psql -t -A -v ON_ERROR_STOP=1 --username="$DB_USER" --dbname="$SOURCE_DB" -c "SELECT COUNT(*) FROM booking_events;")
RESTORE_EVENTS=$(docker compose exec -T "$DB_SERVICE" psql -t -A -v ON_ERROR_STOP=1 --username="$DB_USER" --dbname="$RESTORE_DB" -c "SELECT COUNT(*) FROM booking_events;")

printf "\n%-20s | %-12s | %-12s | %-8s\n" "Table" "Source Rows" "Restored" "Match?"
printf "%-20s-+-%-12s-+-%-12s-+-%-8s\n" "--------------------" "------------" "------------" "--------"
printf "%-20s | %-12s | %-12s | %-8s\n" "hotel_bookings" "$SOURCE_BOOKINGS" "$RESTORE_BOOKINGS" "$([ "$SOURCE_BOOKINGS" -eq "$RESTORE_BOOKINGS" ] && echo "YES" || echo "NO")"
printf "%-20s | %-12s | %-12s | %-8s\n" "booking_events" "$SOURCE_EVENTS" "$RESTORE_EVENTS" "$([ "$SOURCE_EVENTS" -eq "$RESTORE_EVENTS" ] && echo "YES" || echo "NO")"
echo ""

if [[ "$SOURCE_BOOKINGS" -ne "$RESTORE_BOOKINGS" || "$SOURCE_EVENTS" -ne "$RESTORE_EVENTS" ]]; then
  echo "Error: Row count mismatch detected between source and restored database!" >&2
  exit 1
fi

if [[ "$RESTORE_BOOKINGS" -lt 100 ]]; then
  echo "Error: Restored hotel_bookings row count ($RESTORE_BOOKINGS) is less than required 100!" >&2
  exit 1
fi

echo "Verification passed: All tables and records match exactly."
