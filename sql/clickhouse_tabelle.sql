-- Tabelle anlegen und {n} Service-Ereignisse erzeugen.
-- Die Werte werden aus der Zeilennummer berechnet (cityHash64), nicht zufällig:
-- jeder Rechner erzeugt exakt dieselben Daten.

DROP TABLE IF EXISTS ereignisse;

CREATE TABLE ereignisse
(
    zeit           DateTime,
    region         LowCardinality(String),
    dienst         LowCardinality(String),
    status         LowCardinality(String),
    fehlertyp      LowCardinality(String),
    antwortzeit_ms UInt32
)
ENGINE = MergeTree
ORDER BY (region, zeit);

-- Ein Jahr Betrieb (2026), 6 Regionen, 5 Dienste, Grundfehlerrate 2 %.
-- Eingebaute Störung: 10.-17.03.2026 scheitern in Köln 30 % der Zahlungen mit Timeout.
INSERT INTO ereignisse
SELECT
    zeit,
    region,
    dienst,
    if(fehler, 'Fehler', 'OK') AS status,
    multiIf(NOT fehler, '', stoerung, 'Timeout',
            ['Timeout', 'HTTP 500', 'Verbindung', 'Validierung'][cityHash64(number, 4) % 4 + 1]) AS fehlertyp,
    toUInt32(if(fehlertyp = 'Timeout', 5000 + cityHash64(number, 5) % 3000,
                40 + cityHash64(number, 6) % 400
                   + if(cityHash64(number, 7) % 100 = 0, cityHash64(number, 8) % 3000, 0))) AS antwortzeit_ms
FROM
(
    SELECT
        number,
        toDateTime('2026-01-01 00:00:00', 'UTC') + cityHash64(number, 1) % 31536000              AS zeit,
        ['Köln', 'Bonn', 'Berlin', 'Hamburg', 'München', 'Frankfurt'][cityHash64(number, 2) % 6 + 1] AS region,
        ['Zahlung', 'Login', 'Suche', 'Warenkorb', 'Versand'][cityHash64(number, 3) % 5 + 1]         AS dienst,
        region = 'Köln' AND dienst = 'Zahlung'
            AND zeit BETWEEN toDateTime('2026-03-10 00:00:00', 'UTC')
                         AND toDateTime('2026-03-17 23:59:59', 'UTC')                           AS stoer_zeitraum,
        stoer_zeitraum AND cityHash64(number, 9) % 100 < 28                                     AS stoerung,
        stoerung OR cityHash64(number, 10) % 100 < 2                                            AS fehler
    FROM numbers({n:UInt64})
);

OPTIMIZE TABLE ereignisse FINAL;
