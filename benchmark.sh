#!/usr/bin/env bash
# Misst jede Demo-Abfrage in ClickHouse und PostgreSQL.
# Pro Abfrage: 1 Aufwärmlauf (Cache füllen), danach RUNS Messläufe, angezeigt wird der Median.
# Aufruf: ./benchmark.sh        oder   RUNS=1 ./benchmark.sh   (schneller)
set -euo pipefail
cd "$(dirname "$0")"
RUNS="${RUNS:-3}"

# Abfrage Nr. $2 aus Datei $1 holen (Blöcke beginnen mit "-- @<nr>")
abfrage() { awk -v nr="$2" '/^-- @/{on = ($2 == "@" nr)} on && !/^--/' "$1"; }
titel()   { grep "^-- @$2 " "$1" | sed "s/^-- @$2 //"; }

zeit_ch() {  # Sekunden
  docker exec ch clickhouse-client --time --format Null -q "$1" 2>&1 >/dev/null | tail -1
}
zeit_pg() {  # Sekunden
  printf '\\timing on\n\\o /dev/null\n%s\n' "$1" \
    | docker exec -i pg psql -q -U postgres 2>&1 | grep -o 'Time: [0-9.]* ms' | tail -1 \
    | awk '{printf "%.3f\n", $2/1000}'
}
median() { sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }

zeilen=$(docker exec ch clickhouse-client -q "SELECT formatReadableQuantity(count()) FROM service_ereignisse")
echo "Datenmenge: $zeilen Zeilen, $RUNS Messläufe je Abfrage (Median)"
printf '\n%-72s %12s %12s %8s\n' "Abfrage" "ClickHouse" "PostgreSQL" "Faktor"

for nr in $(grep -o '^-- @[0-9]*' sql/abfragen_clickhouse.sql | tr -d '@- '); do
  q_ch=$(abfrage sql/abfragen_clickhouse.sql "$nr")
  q_pg=$(abfrage sql/abfragen_postgres.sql "$nr")
  zeit_ch "$q_ch" >/dev/null; zeit_pg "$q_pg" >/dev/null      # Aufwärmen
  ch=$(for i in $(seq "$RUNS"); do zeit_ch "$q_ch"; done | median)
  pg=$(for i in $(seq "$RUNS"); do zeit_pg "$q_pg"; done | median)
  faktor=$(awk -v a="$pg" -v b="$ch" 'BEGIN{printf "%.0fx", a/b}')
  printf '%-72s %10.2f s %10.2f s %8s\n' "$nr) $(titel sql/abfragen_clickhouse.sql "$nr")" "$ch" "$pg" "$faktor"
done
