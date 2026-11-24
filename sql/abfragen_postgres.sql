-- @1 Daten: Wie viele Service-Ereignisse haben wir?
SELECT count(*)                                  AS ereignisse,
       min(zeit)                                 AS von,
       max(zeit)                                 AS bis
FROM service_ereignisse;

-- @2 Wo? In welcher Region gibt es die meisten Fehler?
SELECT region,
       count(*)                                  AS fehler
FROM service_ereignisse
WHERE fehlertyp != 'kein Fehler'
GROUP BY region
ORDER BY fehler DESC, region;

-- @3 Wann? Fehler pro Woche in Köln
SELECT (date_trunc('week', zeit + interval '1 day')
        - interval '1 day')::date                AS woche,
       count(*)                                  AS fehler
FROM service_ereignisse
WHERE region = 'Köln' AND fehlertyp != 'kein Fehler'
  AND zeit >= '2026-01-04' AND zeit < '2026-04-26'
GROUP BY woche
ORDER BY woche;

-- @4 Warum? Fehler in Köln vom 10. bis 17. März nach Dienst und Fehlertyp
SELECT dienst,
       fehlertyp,
       count(*)                                  AS fehler
FROM service_ereignisse
WHERE region = 'Köln' AND fehlertyp != 'kein Fehler'
  AND zeit BETWEEN '2026-03-10' AND '2026-03-17'
GROUP BY dienst, fehlertyp
ORDER BY fehler DESC, dienst, fehlertyp
LIMIT 5;

-- @5 Vergleich: Antwortzeiten je Dienst bei 10 Mio. Zeilen
SELECT dienst,
       round(avg(antwortzeit_ms))                AS durchschnitt,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY antwortzeit_ms)) AS p95
FROM ereignisse_10mio
GROUP BY dienst
ORDER BY dienst;
