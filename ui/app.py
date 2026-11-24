"""Kleiner Vermittler zwischen Browser und den beiden Datenbanken.

Läuft als eigener Container (siehe docker-compose.yml) und liefert
die Weboberfläche unter http://localhost:8080 aus.
"""
import json
import re
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import psycopg

CH_URL = "http://clickhouse:8123/"
PG_DSN = "host=postgres user=postgres password=demo dbname=postgres"
SQL = Path("/app/sql")
PG_ZEILEN = ("SELECT coalesce(obj_description(oid, 'pg_class')::bigint, "
             "greatest(reltuples, 0)::bigint) FROM pg_class "
             "WHERE relname = %s AND relkind = 'r'")
CH_ZEILEN = ("SELECT total_rows FROM system.tables "
             "WHERE database = currentDatabase() AND name = {t:String}")
TABELLEN = ["service_ereignisse", "ereignisse_10mio"]
HIER = Path(__file__).parent


# ---------- ClickHouse über die eingebaute HTTP-Schnittstelle ----------
def ch(sql, **params):
    q = {"query": sql, **{f"param_{k}": v for k, v in params.items()}}
    req = urllib.request.Request(CH_URL + "?" + urllib.parse.urlencode(q), method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read().decode()


def tabelle(sql):
    return re.search(r"\bFROM (\w+)", sql)[1]


def ch_json(sql):
    d = json.loads(ch(sql + " FORMAT JSONCompact"))
    s = d["statistics"]
    return [m["name"] for m in d["meta"]], d["data"], s["elapsed"], [
        s["rows_read"], s["bytes_read"], int(ch(CH_ZEILEN, t=tabelle(sql)))]


# ---------- PostgreSQL ----------
def pg_run(sql):
    with psycopg.connect(PG_DSN, autocommit=True) as con, con.cursor() as cur:
        start = time.perf_counter()
        cur.execute(sql)
        zeilen = cur.fetchall()
        dauer = time.perf_counter() - start
        spalten = [c.name for c in cur.description]
        t = tabelle(sql)
        zeilenzahl = con.execute(PG_ZEILEN, [t]).fetchone()[0]
        gelesen = [zeilenzahl, con.execute("SELECT pg_relation_size(%s::regclass)", [t]).fetchone()[0], zeilenzahl]
        return spalten, [[str(v) for v in z] for z in zeilen], dauer, gelesen


def pg_wert(sql, werte=None):
    try:
        with psycopg.connect(PG_DSN, autocommit=True, connect_timeout=2) as con:
            return con.execute(sql, werte).fetchone()[0]
    except Exception:
        return None


def ch_wert(sql, **params):
    try:
        return ch(sql, **params).strip() or None
    except Exception:
        return None


# ---------- Abfragen aus den SQL-Dateien ----------
def abfragen():
    def lesen(datei):
        bloecke = {}
        for teil in re.split(r"^-- @", (SQL / datei).read_text(), flags=re.M)[1:]:
            kopf, _, rumpf = teil.partition("\n")
            nr, _, titel = kopf.partition(" ")
            bloecke[nr] = (titel.strip(), rumpf.strip().rstrip(";"))
        return bloecke

    p, c = lesen("abfragen_postgres.sql"), lesen("abfragen_clickhouse.sql")
    return [{"nr": nr, "titel": c[nr][0], "pg": p[nr][1], "ch": c[nr][1]} for nr in c]


# ---------- Daten laden (läuft im Hintergrund) ----------
laden_status = {"laeuft": False, "log": []}


def log(text):
    laden_status["log"].append(text)


def daten_laden(n):
    laden_status.update(laeuft=True, log=[])
    try:
        t = time.time()
        log(f"ClickHouse: {n:,} Zeilen erzeugen …".replace(",", "."))
        skript = (SQL / "clickhouse_tabelle.sql").read_text()
        skript = re.sub(r"^--.*$", "", skript, flags=re.M)
        for befehl in [b.strip() for b in skript.split(";") if b.strip()]:
            ch(befehl, n=n)
        log(f"ClickHouse fertig nach {time.time() - t:.0f} s")

        t = time.time()
        log("PostgreSQL: dieselben Zeilen aus ClickHouse übernehmen …")
        with psycopg.connect(PG_DSN, autocommit=True) as con:
            con.execute((SQL / "postgres_tabelle.sql").read_text())
            for name in TABELLEN:
                log(f"PostgreSQL: {name} …")
                req = urllib.request.Request(
                    CH_URL + "?" + urllib.parse.urlencode({"query": f"SELECT * FROM {name} FORMAT CSV"}),
                    method="POST")
                with urllib.request.urlopen(req, timeout=3600) as r, con.cursor() as cur:
                    with cur.copy(f"COPY {name} FROM STDIN WITH (FORMAT csv)") as copy:
                        while block := r.read(1 << 20):
                            copy.write(block)
                con.execute(f"VACUUM ANALYZE {name}")
                anzahl = con.execute(f"SELECT count(*) FROM {name}").fetchone()[0]
                con.execute(f"COMMENT ON TABLE {name} IS '{int(anzahl)}'")
        log(f"PostgreSQL fertig nach {time.time() - t:.0f} s")
        log("Fertig.")
    except Exception as e:
        log(f"FEHLER: {e}")
    finally:
        laden_status["laeuft"] = False


# ---------- HTTP ----------
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def senden(self, daten, typ="application/json", code=200):
        body = daten if isinstance(daten, bytes) else json.dumps(daten).encode()
        self.send_response(code)
        self.send_header("Content-Type", typ)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        pfad = urllib.parse.urlparse(self.path).path
        if pfad == "/":
            self.senden((HIER / "index.html").read_bytes(), "text/html; charset=utf-8")
        elif pfad == "/api/status":
            self.senden({
                # Nur Metadaten lesen (sofort), damit die Statusanzeige laufende Messungen nicht bremst
                "ch": ch_wert(CH_ZEILEN, t=TABELLEN[0]),
                # exakte Zahl steht nach dem Laden als Kommentar an der Tabelle, sonst Schätzung
                "pg": pg_wert(PG_ZEILEN, [TABELLEN[0]]),
                "ch_bereit": ch_wert("SELECT 1") is not None,
                "pg_bereit": pg_wert("SELECT 1") is not None,
                "laedt": laden_status["laeuft"],
            })
        elif pfad == "/api/abfragen":
            self.senden(abfragen())
        elif pfad == "/api/speicher":
            self.senden({
                "ch": int(ch_wert("SELECT sum(bytes_on_disk) FROM system.parts "
                                  "WHERE active AND table = 'ereignisse_10mio'") or 0),
                "pg": int(pg_wert("SELECT pg_total_relation_size('ereignisse_10mio')") or 0),
            })
        elif pfad == "/api/laden":
            self.senden(laden_status)
        else:
            self.senden({"fehler": "nicht gefunden"}, code=404)

    def do_POST(self):
        pfad = urllib.parse.urlparse(self.path).path
        laenge = int(self.headers.get("Content-Length") or 0)
        daten = json.loads(self.rfile.read(laenge) or b"{}")
        if pfad == "/api/run":
            q = next(a for a in abfragen() if a["nr"] == str(daten["nr"]))
            try:
                if daten["db"] == "ch":
                    spalten, zeilen, sek, gelesen = ch_json(q["ch"])
                else:
                    spalten, zeilen, sek, gelesen = pg_run(q["pg"])
                self.senden({"spalten": spalten, "zeilen": zeilen, "sekunden": sek, "gelesen": gelesen})
            except Exception as e:
                self.senden({"fehler": str(e)}, code=500)
        elif pfad == "/api/laden":
            if not laden_status["laeuft"]:
                threading.Thread(target=daten_laden, args=(int(daten.get("n", 100_000_000)),),
                                 daemon=True).start()
            self.senden({"ok": True})
        else:
            self.senden({"fehler": "nicht gefunden"}, code=404)


if __name__ == "__main__":
    print("Demo-Oberfläche: http://localhost:8080", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
