-- @1 Zählen: Wie viele Fehler gab es insgesamt?
SELECT count() AS fehler
FROM ereignisse
WHERE status = 'Fehler';

-- @2 Gruppieren: Fehlerquote je Region
SELECT region,
       count()                                   AS ereignisse,
       round(100 * avg(status = 'Fehler'), 2)    AS fehler_prozent
FROM ereignisse
GROUP BY region
ORDER BY fehler_prozent DESC, region;

-- @3 Rechnen: Durchschnitt und 95-%-Perzentil der Antwortzeit je Dienst
SELECT dienst,
       round(avg(antwortzeit_ms))                AS avg_ms,
       quantileExact(0.95)(antwortzeit_ms)       AS p95_ms
FROM ereignisse
GROUP BY dienst
ORDER BY avg_ms DESC, dienst;

-- @4 Schwer: 95-%-Perzentil je Region und Tag (ca. 2.200 Gruppen), die 8 schlimmsten Tage
SELECT region,
       toDate(zeit)                              AS tag,
       count()                                   AS ereignisse,
       quantileExact(0.95)(antwortzeit_ms)       AS p95_ms
FROM ereignisse
GROUP BY region, tag
ORDER BY p95_ms DESC, region, tag
LIMIT 8;
