#!/bin/bash
# Doppelklick im Finder: startet ClickHouse, PostgreSQL und die Weboberfläche
# und öffnet http://localhost:8080 im Browser.
cd "$(dirname "$0")"

if ! docker info >/dev/null 2>&1; then
  echo "Docker Desktop wird gestartet …"
  open -a Docker
  until docker info >/dev/null 2>&1; do sleep 2; done
fi

echo "Container starten …"
docker compose up -d --build || { echo; echo "Fehler beim Starten. Fenster schließt in 60 s."; sleep 60; exit 1; }

echo "Warten auf die Weboberfläche …"
until curl -s http://localhost:8080 >/dev/null; do sleep 1; done
open http://localhost:8080
echo "Läuft. Dieses Fenster kann geschlossen werden."
