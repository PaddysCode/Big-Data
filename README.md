# ClickHouse vs. PostgreSQL – Live-Demo

Demo zum Vortrag „ClickHouse – Spaltenorientierte analytische Datenbank für Big Data“
(Big Data Analyse und Visualisierung, H-BRS, 27.11.2026).

Beide Datenbanken bekommen **exakt dieselben 100 Mio. Service-Ereignisse**, dann laufen
dieselben Abfragen in beiden. Nur Open-Source-Versionen, alles lokal in Docker.

## Schnellstart mit Weboberfläche

Voraussetzungen: [Docker Desktop](https://www.docker.com/products/docker-desktop/),
ca. 8 GB RAM für Docker, ca. 12 GB freier Speicher.

```bash
git clone https://github.com/PaddysCode/Big-Data.git
```

1. Im Finder im Ordner `Big-Data` auf **`Demo starten.command`** doppelklicken
   (oder im Terminal: `docker compose up -d --build`, dann http://localhost:8080 öffnen).
   Das startet ClickHouse, PostgreSQL und die Weboberfläche und öffnet den Browser.
2. Einmalig oben rechts auf **„Daten laden“** klicken (ca. 4–5 Minuten).
3. Schritt wählen, **„Beide starten“**: links PostgreSQL, rechts ClickHouse, gleichzeitig,
   mit Live-Stoppuhr, Ergebnis und Faktor.

Tastatur: `Leertaste` starten · `1`–`5` Schritt · `←` `→` blättern · `F` Vollbild

**Wichtig:** Vor dem Vortrag jede Abfrage einmal laufen lassen. Direkt nach dem Laden ist der
Cache kalt, PostgreSQL braucht dann deutlich länger.

Beim ersten Start muss macOS evtl. das Öffnen erlauben: Rechtsklick auf die Datei → „Öffnen“.

Stoppen: `docker compose stop` · Alles löschen: `docker compose down -v`

## Ohne Weboberfläche (Terminal)

```bash
./vorbereiten.sh
```

Das Skript
1. startet ClickHouse 26.8 und PostgreSQL 16 (`docker-compose.yml`),
2. erzeugt in ClickHouse 100 Mio. Zeilen und daraus eine Vergleichstabelle mit 10 Mio. (`sql/clickhouse_tabelle.sql`),
3. kopiert genau diese Zeilen nach PostgreSQL,
4. zeigt Zeilenzahl und Speicherplatz beider Datenbanken.

Die Daten werden aus der Zeilennummer berechnet, nicht zufällig erzeugt. Jeder Rechner hat
deshalb dieselben Daten und dieselben Ergebnisse, nur die Zeiten unterscheiden sich.

Andere Datenmenge: `./vorbereiten.sh 20000000`

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

Gemessen am 23.11.2026 mit `./benchmark.sh`, MacBook (Apple M6, Docker mit 8 GB RAM), 100 Mio. Zeilen, Schritt 5 mit 10 Mio.:

| Abfrage | ClickHouse | PostgreSQL | Faktor |
|---|---:|---:|---:|
| 1) Daten: Wie viele Service-Ereignisse haben wir? | 0,11 s | 2,33 s | 21× |
| 2) Wo? In welcher Region gibt es die meisten Fehler? | 0,12 s | 2,41 s | 19× |
| 3) Wann? Fehler pro Woche in Köln | 0,03 s | 2,43 s | 84× |
| 4) Warum? Fehler in Köln nach Dienst und Fehlertyp | 0,01 s | 2,52 s | 280× |
| 5) Vergleich: Antwortzeiten je Dienst bei 10 Mio. Zeilen | 0,06 s | 5,99 s | 100× |
| Speicherbedarf bei 10 Mio. Zeilen | 78 MB | 734 MB | 9× |

## Die Daten

Tabelle `service_ereignisse` (100 Mio. Zeilen): `zeit`, `region` (6), `dienst` (5), `fehlertyp`, `status`,
`antwortzeit_ms`. Ein Jahr (2026), Grundfehlerrate 2 %. `ereignisse_10mio` ist ein Zehntel davon für den Vergleich in Schritt 5.

**Eingebaute Störung:** 10.–17.03.2026 scheitern in Köln 30 % der Zahlungen mit Timeout.
Die Abfragen finden sie Schritt für Schritt: wo (2), wann (3), warum (4). Schritt 5 ist der Vergleich von Folie 13.

## Fairness

- Gleiche Daten, gleiche Abfragen, gleicher Rechner, beide in Docker
- Vor dem Messen ein Aufwärmlauf, damit beide Datenbanken einen warmen Cache haben
- PostgreSQL mit vernünftigen Einstellungen statt der sehr kleinen Standardwerte
  (`shared_buffers=1GB`, `work_mem=256MB`, 4 parallele Worker)
- Kein Index in PostgreSQL: Schritt 1, 2 und 5 werten viele Zeilen aus, da hilft ein Index kaum. Bei Schritt 3 und 4 würde
  ein Index auf `(region, zeit)` helfen, ClickHouse hat diese Sortierung eingebaut.
- PostgreSQL ist nicht schlecht, sondern für Transaktionen (OLTP) gebaut, ClickHouse für Analysen (OLAP).

## Aufräumen

```bash
docker compose down -v   # Container und Daten löschen
```
