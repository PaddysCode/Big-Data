#!/usr/bin/env bash
# Startet ClickHouse + PostgreSQL und lädt in beide exakt dieselben Daten.
# Aufruf:  ./vorbereiten.sh            (Standard-Datenmenge)
#          ./vorbereiten.sh 10000000   (eigene Zeilenzahl)
set -euo pipefail
cd "$(dirname "$0")"

N="${1:-20000000}"
echo "==> Datenmenge: $N Zeilen"

echo "==> Container starten"
docker compose up -d

echo "==> Warten, bis beide Datenbanken bereit sind"
until docker exec ch clickhouse-client -q "SELECT 1" >/dev/null 2>&1; do sleep 1; done
until docker exec pg pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
sleep 2

echo "==> ClickHouse: Tabelle anlegen und Daten erzeugen"
start=$(date +%s)
docker exec -i ch clickhouse-client --multiquery --param_n="$N" < sql/clickhouse_tabelle.sql
echo "    fertig nach $(( $(date +%s) - start )) s"

echo "==> PostgreSQL: gleiche Daten aus ClickHouse übernehmen (dauert länger)"
start=$(date +%s)
docker exec -i pg psql -q -U postgres < sql/postgres_tabelle.sql
docker exec ch clickhouse-client -q "SELECT * FROM ereignisse FORMAT CSV" \
  | docker exec -i pg psql -q -U postgres -c "\copy ereignisse FROM STDIN WITH (FORMAT csv)"
docker exec pg psql -q -U postgres -c "VACUUM ANALYZE ereignisse"
echo "    fertig nach $(( $(date +%s) - start )) s"

echo "==> Kontrolle: Zeilen und Speicherplatz"
docker exec ch clickhouse-client -q "
  SELECT 'ClickHouse' AS db, count() AS zeilen,
         (SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts
          WHERE active AND table = 'ereignisse') AS speicher
  FROM ereignisse FORMAT PrettyCompactMonoBlock"
docker exec pg psql -U postgres -c "
  SELECT 'PostgreSQL' AS db, count(*) AS zeilen,
         pg_size_pretty(pg_total_relation_size('ereignisse')) AS speicher
  FROM ereignisse"

echo "==> Fertig. Weiter mit: ./benchmark.sh  oder Live-Demo.md"
