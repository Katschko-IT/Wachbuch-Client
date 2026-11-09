# Server-Kopplung

Dieses Client-Repo gehört zu:

**https://github.com/Katschko-IT/Rettungswache-Wachbuch**

## Versionen

| Client | Server |
| --- | --- |
| App 1.2.x | alle Funktionen ab Server **0.28.0**; mindestens **0.25.0**, dann wie 1.1 (Funktionen von 0.28 ausgeblendet) |
| App 1.1.x | mindestens **0.25.0** (Paginierung, `scope`); Monatsbeitrag der Kaffeekasse ab **0.26.0** |
| App 0.2.x | API `/api/v1/` ab Server **0.14.1** (historisch) |

Die App erkennt den API-Stand an Feldern und Endpunkten (`item_details`,
`/dienstanweisungen/`) und an den Fähigkeiten der Discovery
(`checklist_item_results`, `checklist_drafts`), nicht nur an der
Versionsnummer. Fehlt etwas, blendet sie die Funktion aus.

## Endpunkte

| Bereich | Server |
| --- | --- |
| Adresse / QR → Login | Discovery `GET /api/v1/` |
| User / Passwort | `POST /api/v1/token/` (Alias `/anmeldung/`), Kopplung `POST /api/v1/token/kopplung/` |
| MFA | App-Token unter `/konto/api/` |
| Station und Rolle | nur aus `GET /api/v1/me/` / `uebersicht/` |
| Übergaben | `/handovers/` oder `/uebergaben/`; ab 0.28 mit `is_paper_backfill` und `occurred_at` (Nachtrag vom Papierbogen, nur Anzeige) |
| Kalender / Kasse | `/kalender/`, `/kaffeekasse/`, `/kaffeekasse/bezahlt/` |
| Checklisten | `GET /checklisten/` (ab 0.28 mit `item_details` und eingebettetem `draft`, der nie in den Offline-Cache kommt) |
| Zwischenstand (0.28) | `GET`/`PUT /checklisten/<id>/zwischenstand/` – gehört der Wache, `PUT` ersetzt ihn vollständig |
| Abschluss | `POST /checklisten/<id>/abschluss/`; ab 0.28 mit `item_results` je Prüfpunkt-Kennung, 201 mit `defects_created`/`defects_linked`, 400 mit `code` `validation_error` und `errors[]` |
| Geräte & Fahrzeuge | `GET /assets/`, `POST /assets/<id>/status/` |
| Mängel | `/defects/`, Fotos `/defects/<id>/attachments/`; „bereits gemeldet“ über den exakten Filter `GET /defects/?active=1&asset=<asset_id>` (0.28) |
| Lesepflicht (0.28) | `GET /dienstanweisungen/?offen=1`, `POST /dienstanweisungen/<id>/quittieren/` mit `revision` (201 neu, 200 schon bestätigt, 409 neuere Version oder nicht quittierbar) |
| Hinweise | `GET /benachrichtigungen/?kinds=…` (nur die Arten, die die App kennt), `POST /benachrichtigungen/<id>/gelesen/` je angezeigtem Hinweis |
| Fahrzeugsperren | `GET /fahrzeuge/sperren/` (lokale Erinnerung zur Freigabe) |

Alle Pfade liegen unter `/api/v1/`. Header: `Authorization: Token <wb_…>`
(widerrufbar).

## Vertrag prüfen

Echte Antworten des Server-Codes für die Endpunkte oben liegen als Fixtures
unter `test/fixtures/server-0.28/`; `test/api_contract_fixtures_test.dart`
liest sie mit den Modellen der App. Auffrischen und Abdeckung:
[API-VERTRAG-FIXTURES.md](API-VERTRAG-FIXTURES.md).

Ausführlich: [docs/API.md im Server](https://github.com/Katschko-IT/Rettungswache-Wachbuch/blob/main/docs/API.md)
