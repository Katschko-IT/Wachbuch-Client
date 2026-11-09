# API-Vertrag mit echten Serverantworten

Stand: App 1.2.0 · API-Stand des Servers 0.28

Die App prüft ihre Kopplung an den Server nicht mit erfundenen Antworten,
sondern mit Antworten, die der echte Server-Code erzeugt hat (Befund T1 der
0.28-Prüfung).

| Teil | Ort |
| --- | --- |
| Erzeuger | `tool/server_contract/generate_fixtures.py` |
| Antworten | `test/fixtures/server-0.28/*.json` (je Datei `status` und `body`) |
| Herkunft | `test/fixtures/server-0.28/_manifest.json` (Serverversion, Commit, eingefrorene Uhr) |
| Test | `test/api_contract_fixtures_test.dart` |

## Was abgedeckt ist

Discovery, `/me/`, Übergaben (Liste, Detail, Nachtrag vom Papierbogen),
Geräte & Fahrzeuge, Mängel (anlegen, Liste, exakter Filter `?asset=`),
Checklisten (`item_details`, gemeinsamer Zwischenstand, Abschluss mit
Prüffehlern 400, mit angelegtem Mangel 201 und – zweiter Lauf, solange der
Mangel offen ist – mit verknüpftem Mangel `defect_linked`/`defects_linked`),
Lesepflicht (`/dienstanweisungen/` mit Titel, Nummer, Version, Frist;
Bestätigen mit 201 und 409), Hinweise aller Arten von 0.28 mit `?kinds=`
(der Text der MPG-Einweisung nennt wie auf dem Server eine Person),
Fahrzeugsperren sowie der Fehlervertrag (401, 422).

Der Test schickt jede Antwort durch die echten Aufrufe und Modelle der App
(`WachbuchApi`, `Checklist`, `ReadingObligation`, `CrewNotice`,
`OfflineCachePolicy` …). Benennt der Server ein Feld um oder ändert eine
Antwortform, schlägt der Test fehl. Ein eigener Test prüft, dass jede Datei
im Manifest steht und im Test gelesen wird.

## Auffrischen

Voraussetzung: ein Checkout des Server-Repositorys und dessen Python-Umgebung
(dieselbe wie für `python manage.py test`).

```bash
export PATH=/pfad/zur/server-venv/bin:$PATH
export DJANGO_SECRET_KEY=ci-only-secret DJANGO_DEBUG=false \
       REDIS_URL= REDIS_HOST= DATABASE_URL=
python tool/server_contract/generate_fixtures.py --server ../Rettungswache-Wachbuch
flutter test test/api_contract_fixtures_test.dart
```

Zum Vergleichen ohne die Fixtures im Repository zu überschreiben:
`--out /tmp/fixtures-neu` (relativ zum Aufrufort, nie im Server-Checkout),
danach `diff -r test/fixtures/server-0.28 /tmp/fixtures-neu`.

Das Skript nutzt `config.test_settings` des Servers, legt eine eigene leere
SQLite-Testdatenbank an (die Datenbank des Servers bleibt unberührt), schreibt
keine `__pycache__`-Dateien in den Server-Checkout, friert
die Uhr auf `2026-11-09T07:00:00Z` ein und ersetzt nur die zufälligen
Korrelations-IDs. Danach `git diff test/fixtures/` lesen: Jede Änderung ist
eine Änderung des Vertrags und gehört in CHANGELOG und Modelle.

Der Ordnername folgt dem API-Stand der App (`--api 0.28`), nicht der
Versionsnummer des Servers: Ein Server-Stand kann die Funktionen von 0.28
enthalten, bevor seine Versionsnummer angehoben ist. Die App erkennt den
API-Stand deshalb auch an den Fähigkeiten der Discovery
(`checklist_item_results`, `checklist_drafts`).

## Datenschutz

Die Musterwache enthält nur Wachalltag mit erfundenen Namen. Keine Patienten-,
Einsatz-, Alarmierungs-, Gesundheits- oder Leistungsdaten, keine Auswertungen
je Person.
