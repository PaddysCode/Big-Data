# ClickHouse vs. PostgreSQL – Live-Demo

Demo zum Vortrag „ClickHouse – Spaltenorientierte analytische Datenbank für Big Data“
(Big Data Analyse und Visualisierung, H-BRS, 27.11.2026).

Beide Datenbanken bekommen **exakt dieselben 20 Mio. Service-Ereignisse**, dann laufen
dieselben Abfragen in beiden. Nur Open-Source-Versionen, alles lokal in Docker.

## Einrichten (einmalig, ca. 2 Minuten)

Voraussetzungen: [Docker Desktop](https://www.docker.com/products/docker-desktop/) läuft,
ca. 8 GB RAM für Docker, ca. 3 GB freier Speicher.

```bash
git clone https://github.com/PaddysCode/Big-Data.git
cd Big-Data
./vorbereiten.sh
```

Das Skript
1. startet ClickHouse 24.8 und PostgreSQL 16 (`docker-compose.yml`),
2. erzeugt in ClickHouse 20 Mio. Zeilen (`sql/clickhouse_tabelle.sql`),
3. kopiert genau diese Zeilen nach PostgreSQL,
4. zeigt Zeilenzahl und Speicherplatz beider Datenbanken.

Die Daten werden aus der Zeilennummer berechnet, nicht zufällig erzeugt. Jeder Rechner hat
deshalb dieselben Daten und dieselben Ergebnisse, nur die Zeiten unterscheiden sich.

Andere Datenmenge: `./vorbereiten.sh 10000000`

## Messen

```bash
./benchmark.sh
```

Führt jede Abfrage aus `sql/` in beiden Datenbanken aus (1× aufwärmen, 3× messen, Median).

## Ergebnisse

Gemessen am 20.11.2026, MacBook Pro (Intel i9, Docker mit 8 GB RAM), 20 Mio. Zeilen:

| Abfrage | ClickHouse | PostgreSQL | Faktor |
|---|---:|---:|---:|
| 1) Fehler zählen | 0,01 s | 0,53 s | 35× |
| 2) Fehlerquote je Region | 0,04 s | 1,35 s | 35× |
| 3) Ø und 95-%-Perzentil je Dienst | 0,13 s | 9,35 s | 74× |
| 4) 95-%-Perzentil je Region und Tag | 0,19 s | 12,19 s | 65× |
| Speicherplatz | 146 MB | 1.199 MB | 8× |

## Die Daten

Tabelle `ereignisse`: `zeit`, `region` (6 Städte), `dienst` (5 Dienste), `status`,
`fehlertyp`, `antwortzeit_ms`. Ein Jahr (2026), Grundfehlerrate 2 %.

**Eingebaute Störung:** 10.–17.03.2026 scheitern in Köln 30 % der Zahlungen mit Timeout.
Abfrage 4 findet genau diese Tage.

## Fairness

- Gleiche Daten, gleiche Abfragen, gleicher Rechner, beide in Docker
- Vor dem Messen ein Aufwärmlauf, damit beide Datenbanken einen warmen Cache haben
- PostgreSQL mit vernünftigen Einstellungen statt der sehr kleinen Standardwerte
  (`shared_buffers=1GB`, `work_mem=256MB`, 4 parallele Worker)
- Kein Index in PostgreSQL: Die Abfragen lesen sowieso die ganze Tabelle, ein Index hilft dabei kaum.
- PostgreSQL ist nicht schlecht, sondern für Transaktionen (OLTP) gebaut, ClickHouse für Analysen (OLAP).

## Aufräumen

```bash
docker compose down -v   # Container und Daten löschen
```
