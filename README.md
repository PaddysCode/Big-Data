# ClickHouse vs. PostgreSQL – Live-Demo

Demo zum Vortrag „ClickHouse – Spaltenorientierte analytische Datenbank für Big Data“
(Big Data Analyse und Visualisierung, H-BRS, 27.11.2026).

Beide Datenbanken bekommen **exakt dieselben 20 Mio. Service-Ereignisse**, dann laufen
dieselben Abfragen in beiden. Nur Open-Source-Versionen, alles lokal in Docker.

## Schnellstart mit Weboberfläche

Voraussetzungen: [Docker Desktop](https://www.docker.com/products/docker-desktop/),
ca. 8 GB RAM für Docker, ca. 3 GB freier Speicher.

```bash
git clone https://github.com/PaddysCode/Big-Data.git
```

1. Im Finder im Ordner `Big-Data` auf **`Demo starten.command`** doppelklicken
   (oder im Terminal: `docker compose up -d --build`, dann http://localhost:8080 öffnen).
   Das startet ClickHouse, PostgreSQL und die Weboberfläche und öffnet den Browser.
2. Einmalig oben rechts auf **„Daten laden“** klicken (ca. 1–2 Minuten).
3. Abfrage wählen, **„Beide starten“**: links PostgreSQL, rechts ClickHouse, gleichzeitig,
   mit Live-Stoppuhr, Ergebnis und Faktor.

Tastatur: `Leertaste` starten · `1`–`4` Abfrage · `←` `→` blättern · `S` Speicherplatz · `F` Vollbild

**Wichtig:** Vor dem Vortrag jede Abfrage einmal laufen lassen. Direkt nach dem Laden ist der
Cache kalt, PostgreSQL braucht dann deutlich länger (gemessen 16 s statt 10 s).

Beim ersten Start muss macOS evtl. das Öffnen erlauben: Rechtsklick auf die Datei → „Öffnen“.

Stoppen: `docker compose stop` · Alles löschen: `docker compose down -v`

## Ohne Weboberfläche (Terminal)

```bash
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

## Demo ansehen

```bash
./demo.sh          # zeigt jeden SQL-Befehl, Enter führt ihn in PostgreSQL und ClickHouse aus
AUTO=1 ./demo.sh   # läuft von allein durch
```

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
