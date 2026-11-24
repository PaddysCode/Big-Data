-- Tabelle anlegen und {n} Service-Ereignisse erzeugen.
-- Die Werte werden aus der Zeilennummer berechnet (cityHash64), nicht zufällig:
-- jeder Rechner erzeugt exakt dieselben Daten.

DROP TABLE IF EXISTS ereignisse;
DROP TABLE IF EXISTS ereignisse_10mio;
DROP TABLE IF EXISTS service_ereignisse;

CREATE TABLE service_ereignisse
(
    zeit           DateTime,
    region         LowCardinality(String),
    dienst         LowCardinality(String),
    fehlertyp      LowCardinality(String),
    status         UInt16,
    antwortzeit_ms UInt32
)
ENGINE = MergeTree
ORDER BY (region, zeit);

-- Ein Jahr Betrieb (2026), 6 Regionen, 5 Dienste, Grundfehlerrate 2 %.
-- Eingebaute Störung: 10.-17.03.2026 scheitern in Köln 30 % der Zahlungen mit Timeout.
INSERT INTO service_ereignisse
SELECT
    zeit,
    region,
    dienst,
    fehlertyp,
    multiIf(fehlertyp = 'kein Fehler', 200, fehlertyp = 'Timeout', 504,
            fehlertyp = 'Ungültige Eingabe', 400, fehlertyp = 'Server überlastet', 503, 500) AS status,
    20 + cityHash64(number, 5) % 300 + if(dienst = 'Zahlung', 150, 0)
       + if(fehlertyp = 'Timeout', 5000, 0) AS antwortzeit_ms
FROM
(
    SELECT
        number,
        toDateTime('2026-01-01 00:00:00', 'UTC') + intDiv(number * 31536000, {n:UInt64})             AS zeit,
        ['Bonn', 'Köln', 'Berlin', 'Hamburg', 'München', 'Frankfurt'][cityHash64(number, 1) % 6 + 1] AS region,
        ['Login', 'Suche', 'Warenkorb', 'Zahlung', 'Versand'][cityHash64(number, 2) % 5 + 1]         AS dienst,
        multiIf(
            region = 'Köln' AND dienst = 'Zahlung'
                AND zeit BETWEEN toDateTime('2026-03-10 00:00:00', 'UTC') AND toDateTime('2026-03-17 00:00:00', 'UTC')
                AND cityHash64(number, 3) % 100 < 30, 'Timeout',
            cityHash64(number, 3) % 100 < 2,
                ['Timeout', 'Datenbankfehler', 'Ungültige Eingabe', 'Server überlastet'][cityHash64(number, 4) % 4 + 1],
            'kein Fehler') AS fehlertyp
    FROM numbers({n:UInt64})
);

OPTIMIZE TABLE service_ereignisse FINAL;

-- Ein Zehntel der Zeilen für den Vergleich (Folie 13)
CREATE TABLE ereignisse_10mio ENGINE = MergeTree ORDER BY (region, zeit) AS
SELECT * FROM service_ereignisse
WHERE cityHash64(zeit, region, dienst, fehlertyp, antwortzeit_ms) % 10 = 0;

OPTIMIZE TABLE ereignisse_10mio FINAL;
