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
HIER = Path(__file__).parent


# ---------- ClickHouse über die eingebaute HTTP-Schnittstelle ----------
def ch(sql, **params):
    q = {"query": sql, **{f"param_{k}": v for k, v in params.items()}}
    req = urllib.request.Request(CH_URL + "?" + urllib.parse.urlencode(q), method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read().decode()


def ch_json(sql):
    d = json.loads(ch(sql + " FORMAT JSONCompact"))
    return [m["name"] for m in d["meta"]], d["data"], d["statistics"]["elapsed"]


# ---------- PostgreSQL ----------
def pg_run(sql):
    with psycopg.connect(PG_DSN, autocommit=True) as con, con.cursor() as cur:
        start = time.perf_counter()
        cur.execute(sql)
        zeilen = cur.fetchall()
        dauer = time.perf_counter() - start
        return [c.name for c in cur.description], [[str(v) for v in z] for z in zeilen], dauer


def pg_wert(sql):
    try:
        with psycopg.connect(PG_DSN, autocommit=True, connect_timeout=2) as con:
            return con.execute(sql).fetchone()[0]
    except Exception:
        return None


def ch_wert(sql):
    try:
        return ch(sql).strip() or None
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
            req = urllib.request.Request(
                CH_URL + "?" + urllib.parse.urlencode({"query": "SELECT * FROM ereignisse FORMAT CSV"}),
                method="POST")
            with urllib.request.urlopen(req, timeout=3600) as r, con.cursor() as cur:
                with cur.copy("COPY ereignisse FROM STDIN WITH (FORMAT csv)") as copy:
                    while block := r.read(1 << 20):
                        copy.write(block)
            log("PostgreSQL: Statistiken aktualisieren (VACUUM ANALYZE) …")
            con.execute("VACUUM ANALYZE ereignisse")
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
                "ch": ch_wert("SELECT count() FROM ereignisse"),
                "pg": pg_wert("SELECT count(*) FROM ereignisse"),
                "ch_bereit": ch_wert("SELECT 1") is not None,
                "pg_bereit": pg_wert("SELECT 1") is not None,
            })
        elif pfad == "/api/abfragen":
            self.senden(abfragen())
        elif pfad == "/api/speicher":
            self.senden({
                "ch": int(ch_wert("SELECT sum(bytes_on_disk) FROM system.parts "
                                  "WHERE active AND table = 'ereignisse'") or 0),
                "pg": int(pg_wert("SELECT pg_total_relation_size('ereignisse')") or 0),
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
                    spalten, zeilen, sek = ch_json(q["ch"])
                else:
                    spalten, zeilen, sek = pg_run(q["pg"])
                self.senden({"spalten": spalten, "zeilen": zeilen, "sekunden": sek})
            except Exception as e:
                self.senden({"fehler": str(e)}, code=500)
        elif pfad == "/api/laden":
            if not laden_status["laeuft"]:
                threading.Thread(target=daten_laden, args=(int(daten.get("n", 20_000_000)),),
                                 daemon=True).start()
            self.senden({"ok": True})
        else:
            self.senden({"fehler": "nicht gefunden"}, code=404)


if __name__ == "__main__":
    print("Demo-Oberfläche: http://localhost:8080", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
