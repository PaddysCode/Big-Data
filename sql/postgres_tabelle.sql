-- Gleiche Tabelle in PostgreSQL. Die Daten kommen per COPY direkt aus ClickHouse.
DROP TABLE IF EXISTS ereignisse;
CREATE TABLE ereignisse (
    zeit           timestamp,
    region         text,
    dienst         text,
    status         text,
    fehlertyp      text,
    antwortzeit_ms integer
);
