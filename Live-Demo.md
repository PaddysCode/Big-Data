# Ablauf Live-Demo (ca. 6 Minuten)

**A** bedient, **B** erzählt.

## Empfohlen: Weboberfläche

- [ ] Vorher: `Demo starten.command` doppelklicken, Daten einmal geladen (oben steht bei beiden 100 Mio. Zeilen)
- [ ] Jeden Schritt einmal gestartet (Cache aufwärmen!)
- [ ] Browser im Vollbild (`F`), die Seite passt sich automatisch an die Bildschirmgröße an
- [ ] Live: Schritt mit `1`–`5` wählen, `Leertaste` startet beide gleichzeitig, B erzählt wie unten

Der Ablauf unten gilt genauso, nur ohne Tippen.

## Alternative: zwei Terminals (vorher, zu Hause / vor dem Vortrag)

- [ ] `./vorbereiten.sh` auf dem Präsentations-Laptop gelaufen, Docker Desktop läuft
- [ ] Ersatz-Laptop ebenfalls vorbereitet
- [ ] Zwei Terminalfenster nebeneinander, Schrift mind. 20 pt, helles Theme
- [ ] Links: `docker exec -it pg psql -U postgres`, dann `\timing on`
- [ ] Rechts: `docker exec -it ch clickhouse-client`
- [ ] Jede Abfrage einmal ausgeführt (Cache aufwärmen), dann `clear` bzw. Strg+L
- [ ] Laptop am Strom, Benachrichtigungen aus, Energiesparen aus
- [ ] Backup-Folien mit den Zahlen aus `README.md` bereit

## Ablauf

Die Demo folgt den Folien 3 und 11 bis 13: Ein Betriebsteam sucht in 100 Mio. Service-Ereignissen eine Störung und vergleicht am Ende beide Datenbanken. Jeder Schritt läuft in beiden gleichzeitig, unter der Frage erscheint die Erkenntnis in Gelb, unten rechts sieht man, was gelesen wird.

| Zeit | Folie | Wer | Was |
|---|---|---|---|
| 0:45 | 3, 11 | A | **Schritt 1 Daten**. B: „Links PostgreSQL, rechts ClickHouse, beide mit exakt denselben 100 Mio. Service-Ereignissen aus einem Jahr. Wo und wann gab es auffällig viele Fehler?“ |
| 1:00 | 11 | A | **Schritt 2 Wo?** B: „Köln fällt auf, rund 18.000 Fehler mehr als die anderen Regionen. PostgreSQL liest dafür alle 6 Spalten, ClickHouse nur 2.“ |
| 1:00 | 12 | A | **Schritt 3 Wann?** B: „Die Woche ab dem 8. März hat dreimal so viele Fehler. ClickHouse überspringt alles, was nicht Köln ist, weil die Daten nach Region und Zeit sortiert sind.“ |
| 1:00 | 12 | A | **Schritt 4 Warum?** B: „Ursache gefunden: Der Dienst Zahlung hatte Timeouts, rund 19.000 Fälle. Drei Abfragen, jeweils deutlich unter einer Sekunde.“ |
| 1:30 | 13 | A | **Schritt 5 Vergleich**. PostgreSQL rechnet rund 6 bis 8 s. B in der Wartezeit: „Hier sind es 10 Mio. Zeilen. Für das 95-%-Perzentil muss jede Antwortzeit angeschaut werden.“ Danach der Speicherbedarf: rund 9-mal weniger. |
| 0:30 | 13 | B | Fazit: „PostgreSQL ist nicht schlecht, es ist für Transaktionen gebaut. ClickHouse für genau diese Analysen.“ |

**Zeiten auf den Folien:** Folie 12 und 13 stammen vom Testlauf am 23.11.2026 auf einem MacBook (Apple M6). Live sind die Zeiten auf einem anderen Rechner anders, dann kurz dazusagen.

**Tipp:** In ClickHouse unter dem Ergebnis auf „Processed 100.00 million rows … (x million rows/s)“ zeigen.

## Variante: alles in einem Terminal mit `./demo.sh`

Statt die Abfragen von Hand zu kopieren, kann A auch `./demo.sh` starten. Das Skript zeigt
jeden SQL-Befehl an und führt ihn nach **Enter** aus: erst in PostgreSQL, dann in ClickHouse,
jeweils mit Ergebnis und Zeit. Weniger Tippfehler-Risiko, dafür nicht nebeneinander.

- `./demo.sh 3 4` zeigt nur die Schritte 3 und 4
- `AUTO=1 ./demo.sh` läuft ohne Enter von allein durch (zum Üben)

## Wenn etwas hakt

Nicht debuggen, sofort auf die Backup-Folie wechseln: „Hier die Ergebnisse aus unserem Testlauf.“

| Problem | Lösung |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop starten, ca. 30 s warten |
| `No such container: ch` | `docker compose up -d` im Projektordner |
| Tabelle fehlt | `./vorbereiten.sh` (ca. 4–5 Min.) |
| PostgreSQL hängt deutlich länger als 15 s | Strg+C, Backup-Folie |
