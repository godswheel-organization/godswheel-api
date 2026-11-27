
#!/usr/bin/env bash
set -euo pipefail

printf 'COLLECTED_AT=%s\n' "$(date --utc '+%Y-%m-%dT%H:%M:%SZ')"
printf 'HOSTNAME=%s\n' "$(hostname)"
printf 'OS=%s\n' "$(. /etc/os-release && printf '%s %s' "$NAME" "$VERSION_ID")"
printf 'UPTIME=%s\n' "$(uptime -p)"
printf 'CPU_CORES=%s\n' "$(nproc)"

printf '\n[EXECUTION_USER]\n'
id

printf '\n[LOAD_AVERAGE]\n'
cat /proc/loadavg

printf '\n[MEMORY]\n'
free -h

printf '\n[DISK]\n'
df -h / /var/lib/pgsql 2>/dev/null || df -h /

printf '\n[POSTGRESQL_SERVICE]\n'
systemctl is-active postgresql || systemctl is-active postgresql-18 || true

printf '\n[POSTGRESQL_DATABASE]\n'

sudo -n -u postgres /usr/bin/psql \
  -X -A -F '|' -t \
  -d godswheel_db \
  -c "
SELECT
  current_setting('server_version') AS postgres_version,
  current_setting('max_connections') AS max_connections,
  (SELECT count(*) FROM pg_stat_activity) AS total_connections,
  (SELECT count(*) FROM pg_stat_activity
    WHERE backend_type = 'client backend'
    AND state = 'active') AS active_client_connections,
  (SELECT count(*) FROM pg_stat_activity
    WHERE backend_type = 'client backend'
    AND state = 'idle') AS idle_client_connections,
  pg_size_pretty(pg_database_size(current_database())) AS database_size;
"

printf '\n[DATABASE_ACTIVITY]\n'

sudo -n -u postgres /usr/bin/psql \
  -X -A -F '|' -t \
  -d godswheel_db \
  -c "
SELECT
  datname,
  numbackends AS current_connections,
  xact_commit AS committed_transactions,
  xact_rollback AS rolled_back_transactions,
  deadlocks,
  conflicts
FROM pg_stat_database
WHERE datname = current_database();
"

printf '\n[METRICS_COLLECTION_STATUS]\n'
echo "SUCCESS"
