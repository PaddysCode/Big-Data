-- Gleiche Tabellen in PostgreSQL. Die Daten kommen per COPY direkt aus ClickHouse.
DROP TABLE IF EXISTS ereignisse;
DROP TABLE IF EXISTS ereignisse_10mio;
DROP TABLE IF EXISTS service_ereignisse;
CREATE TABLE service_ereignisse (
    zeit           timestamp,
    region         text,
    dienst         text,
    fehlertyp      text,
    status         smallint,
    antwortzeit_ms integer
);
CREATE TABLE ereignisse_10mio (LIKE service_ereignisse);
