#!/usr/bin/env bash
# Spielt die Demo-Abfragen nacheinander ab: zeigt den SQL-Befehl,
# führt ihn erst in PostgreSQL, dann in ClickHouse aus und zeigt Ergebnis und Zeit.
#   ./demo.sh          wartet vor jedem Schritt auf Enter (zum Präsentieren)
#   AUTO=1 ./demo.sh   läuft von allein durch (zum Zuschauen)
#   ./demo.sh 3 4      nur bestimmte Abfragen
cd "$(dirname "$0")"

B=$'\e[1m'; C=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[0m'
abfrage() { awk -v nr="$2" '/^-- @/{on = ($2 == "@" nr)} on && !/^--/' "$1"; }
titel()   { grep "^-- @$1 " sql/abfragen_clickhouse.sql | sed "s/^-- @$1 //"; }
weiter()  { if [ -n "${AUTO:-}" ]; then sleep "${PAUSE:-3}"; else read -rsp "${Y}[Enter]${R}" _; echo; fi; }

nummern="${*:-1 2 3 4 5}"
for nr in $nummern; do
  echo; echo "${B}════════ Abfrage $nr: $(titel "$nr") ════════${R}"

  echo; echo "${B}${C}▶ PostgreSQL${R}"
  echo "${C}$(abfrage sql/abfragen_postgres.sql "$nr")${R}"
  weiter
  echo "${Y}… läuft${R}"
  printf '\\timing on\n%s\n' "$(abfrage sql/abfragen_postgres.sql "$nr")" \
    | docker exec -i pg psql -q -U postgres \
    | awk -v b="$B" -v r="$R" '/^Time: /{printf "%s⏱  PostgreSQL: %.3f s%s\n", b, $2/1000, r; next} {print}'

  echo; echo "${B}${G}▶ ClickHouse${R}"
  echo "${G}$(abfrage sql/abfragen_clickhouse.sql "$nr")${R}"
  weiter
  echo "${Y}… läuft${R}"
  docker exec -t ch clickhouse-client --time --format PrettyCompactMonoBlock \
    -q "$(abfrage sql/abfragen_clickhouse.sql "$nr")" 2>&1 \
    | sed -E "s/^([0-9]+\.[0-9]+)\r?$/${B}⏱  ClickHouse: \\1 s${R}/"
  weiter
done
echo; echo "${B}Fertig.${R}"
