# Ablauf Live-Demo (ca. 5 Minuten)

**A** tippt, **B** erzählt. Alle Abfragen stehen in `sql/abfragen_*.sql` zum Kopieren.

## Vorher (zu Hause / vor dem Vortrag)

- [ ] `./vorbereiten.sh` auf dem Präsentations-Laptop gelaufen, Docker Desktop läuft
- [ ] Ersatz-Laptop ebenfalls vorbereitet
- [ ] Zwei Terminalfenster nebeneinander, Schrift mind. 20 pt, helles Theme
- [ ] Links: `docker exec -it pg psql -U postgres`, dann `\timing on`
- [ ] Rechts: `docker exec -it ch clickhouse-client`
- [ ] Jede Abfrage einmal ausgeführt (Cache aufwärmen), dann `clear` bzw. Strg+L
- [ ] Laptop am Strom, Benachrichtigungen aus, Energiesparen aus
- [ ] Backup-Folien mit den Zahlen aus `README.md` bereit

## Ablauf

| Zeit | Wer | Was |
|---|---|---|
| 0:30 | B | „Links PostgreSQL, rechts ClickHouse. Beide haben exakt dieselben 20 Millionen Service-Ereignisse.“ |
| 0:30 | A | In beiden: **Abfrage 1** (Fehler zählen). B: „Selbst einfaches Zählen: halbe Sekunde gegen sofort.“ |
| 1:30 | A | **Abfrage 3** zuerst links, Enter, dann sofort rechts, Enter. B: „Durchschnitt und 95-%-Perzentil der Antwortzeit je Dienst, eine typische Dashboard-Frage.“ ClickHouse ist sofort fertig, PostgreSQL rechnet ca. 10 s. B in der Wartezeit: „ClickHouse liest nur die zwei Spalten, die es braucht, PostgreSQL jede Zeile komplett.“ |
| 1:30 | A | **Abfrage 4** genauso. B: „Jetzt pro Region und Tag, die zehn schlimmsten Tage.“ Ergebnis: Köln, 10.–17. März. „Da ist unsere eingebaute Störung, gefunden in 0,2 Sekunden.“ |
| 0:30 | B | Speicherplatz (aus `./vorbereiten.sh`): 146 MB gegen 1,2 GB. „Spalten lassen sich viel besser komprimieren.“ |
| 0:30 | B | Fazit: „Rund 35- bis 75-mal schneller und 8-mal kleiner. PostgreSQL ist nicht schlecht, es ist für Transaktionen gebaut. ClickHouse für genau diese Analysen.“ |

**Tipp:** In ClickHouse unter dem Ergebnis auf „Processed 20.00 million rows … (x million rows/s)“ zeigen.

## Wenn etwas hakt

Nicht debuggen, sofort auf die Backup-Folie wechseln: „Hier die Ergebnisse aus unserem Testlauf.“

| Problem | Lösung |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop starten, ca. 30 s warten |
| `No such container: ch` | `docker compose up -d` im Projektordner |
| Tabelle fehlt | `./vorbereiten.sh` (ca. 1–2 Min.) |
| PostgreSQL hängt deutlich länger als 15 s | Strg+C, Backup-Folie |
