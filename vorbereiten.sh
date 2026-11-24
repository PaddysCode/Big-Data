#!/usr/bin/env bash
# Startet ClickHouse + PostgreSQL und lädt in beide exakt dieselben Daten.
# Aufruf:  ./vorbereiten.sh            (Standard-Datenmenge)
#          ./vorbereiten.sh 20000000   (eigene Zeilenzahl)
set -euo pipefail
cd "$(dirname "$0")"

N="${1:-100000000}"
echo "==> Datenmenge: $N Zeilen"

echo "==> Container starten"
if docker inspect ch pg >/dev/null 2>&1; then
  docker start ch pg >/dev/null     # gibt es schon (z. B. aus einem anderen Ordner)
else
  docker compose up -d
fi

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
for t in service_ereignisse ereignisse_10mio; do
  docker exec ch clickhouse-client -q "SELECT * FROM $t FORMAT CSV" \
    | docker exec -i pg psql -q -U postgres -c "\copy $t FROM STDIN WITH (FORMAT csv)"
  docker exec pg psql -q -U postgres -c "VACUUM ANALYZE $t"
  docker exec pg psql -q -U postgres -c "DO \$\$ BEGIN EXECUTE format('COMMENT ON TABLE $t IS %L', (SELECT count(*) FROM $t)); END \$\$"
done
echo "    fertig nach $(( $(date +%s) - start )) s"

echo "==> Kontrolle: Zeilen und Speicherplatz"
docker exec ch clickhouse-client -q "
  SELECT 'ClickHouse' AS db, count() AS zeilen,
         (SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts
          WHERE active AND table = 'service_ereignisse') AS speicher
  FROM service_ereignisse FORMAT PrettyCompactMonoBlock"
docker exec pg psql -U postgres -c "
  SELECT 'PostgreSQL' AS db, count(*) AS zeilen,
         pg_size_pretty(pg_total_relation_size('service_ereignisse')) AS speicher
  FROM service_ereignisse"

echo "==> Fertig. Weiter mit: ./benchmark.sh  oder Live-Demo.md"
