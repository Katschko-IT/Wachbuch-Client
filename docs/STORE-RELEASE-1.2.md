# Store Release 1.2 – Abnahmeplan

Stand: 9. November 2026  
Geplanter Build: **1.2.0+14**

Dieses Dokument ergänzt [`STORE-RELEASE-1.1.md`](STORE-RELEASE-1.1.md) und [`STORE-RELEASE-1.0.md`](STORE-RELEASE-1.0.md). Identitäten, Signierung, Store-Konten, Rollout-Reihenfolge und die manuellen Schritte in App Store Connect und Play Console gelten unverändert weiter; hier steht nur, was für 1.2 neu oder anders ist.

## 1. Inhalt und Paarung

- **Server:** Die neuen Funktionen brauchen den API-Stand **0.28.0**. Mit Servern ab **0.25.0** läuft 1.2 wie 1.1 und blendet aus, was fehlt. Die App erkennt den API-Stand an Feldern und Endpunkten (`item_details`, `/api/v1/dienstanweisungen/`) und an den Fähigkeiten der Discovery (`checklist_item_results`, `checklist_drafts`), nicht nur an `app_version`.
- **Neu gegenüber 1.1.0+13:** Checklisten mit Ergebnis je Prüfpunkt, Messwerten und Grenzwerten; Zwischenstand der Wache speichern und fortsetzen; Prüffehler am Prüfpunkt; „Mangel in drei Tipps“ mit Kamera zuerst, Bezugsauswahl, QR-Code und Hinweis „bereits gemeldet“; Lesepflicht für Dienstanweisungen; Hinweise von 0.28 im Posteingang; Kennzeichen für Nachträge vom Papierbogen.
- **Build-Nummer:** 14 muss größer sein als jede jemals in Play Console oder App Store Connect hochgeladene Build-Nummer.
- **Secure Storage:** unverändert `flutter_secure_storage` 10.x, keine neue Speicher-Migration.
- **Offline-Cache:** `schema_version` bleibt 1. Die Checklisten im Cache bekommen `item_details` dazu; der Zwischenstand `draft` wird vor dem Schreiben entfernt. Alte 1.1-Einträge ohne `item_details` bleiben lesbar (Abschluss mit einem Tipp, offline ohnehin nicht möglich).
- **Android-Berechtigungen:** unverändert gegenüber 1.1 (`ACCESS_COARSE_LOCATION`, `ACCESS_NETWORK_STATE`, `CAMERA`, `INTERNET`, `POST_NOTIFICATIONS`, `VIBRATE` plus Receiver-Berechtigung). Die Kamera hat einen dritten Zweck (QR-Code an Fahrzeug oder Gerät), aber keine neue Berechtigung.

## 2. Automatische Gates

Wie 1.1 (Abschnitt 2 dort). Zusätzlich:

- `test/api_contract_fixtures_test.dart` ist grün mit Fixtures, die aus dem Server-Stand der Freigabe erzeugt wurden (`test/fixtures/server-0.28/_manifest.json`: Serverversion und Commit). Vor dem Release-PR einmal neu erzeugen und den Diff prüfen ([`API-VERTRAG-FIXTURES.md`](API-VERTRAG-FIXTURES.md)).
- Der früher rote Test „initial Wachwerk link selects server and clears old token“ ist grün (deterministisch, ohne echte SharedPreferences).

## 3. Rollout

1. PR auf `main` mit grünen Gates mergen.
2. **Server zuerst:** Wachen, die 1.2 vollständig nutzen sollen, brauchen 0.28. Ein Update der App vor dem Server ist unkritisch (1.2 verhält sich dann wie 1.1).
3. **Android:** Workflow **Android Signed Release** auf `main` mit `1.2.0` / `14`; Play Console: interner Test → geschlossener Test → gestaffelte Produktion.
4. **iOS:** Workflow **TestFlight** mit `1.2.0` / `14`, sobald `ios.yml` auf `main` grün ist; danach App Store.
5. Tag `v1.2.0` auf den Release-Commit.

### Erzwungenes Update

Für 1.2 nicht nötig: 1.1 bleibt mit 0.28 lauffähig (0.28 ist additiv; Checklisten mit Prüfpunkten verlangen dort allerdings Ergebnisse je Punkt, 1.1 zeigt dann die Fehlermeldung des Servers). Wer den Abschluss mit einem Tipp auf 0.28 verhindern will, setzt nach Live-Schaltung einen `AppVersion`-Eintrag mit `min_required_version` `1.2.0` wie in 1.1 beschrieben.

## 4. Upgrade-Matrix auf echten Geräten

| Ausgangsstand | Ziel | Server | Erwartung |
| --- | --- | --- | --- |
| 1.1.0+13 | 1.2.0+14 | 0.27 | Sitzung bleibt angemeldet; Checklisten wie bisher mit einem Tipp; kein Lesepflicht-Eintrag; kein Hinweis „bereits gemeldet“. |
| 1.1.0+13 | 1.2.0+14 | 0.28 | Sitzung bleibt angemeldet; Checklisten mit Prüfpunkten öffnen den Lauf; offener Zwischenstand aus dem Web wird fortgesetzt; Lesepflicht auf der Startseite, sobald etwas offen ist. |
| 1.0.0+12 | 1.2.0+14 | 0.28 | wie 1.0 → 1.1 (`STORE-RELEASE-1.1.md`), danach wie oben. |

## 5. Manuelle Prüfungen

Zusätzlich zu den Prüfungen aus 1.1 (Abschnitt 5 dort), gegen einen Server mit 0.28:

1. Checkliste mit Messpunkt (z. B. 2–8 °C): Wert 9,5 eingeben → Hinweis „Außerhalb der Grenzwerte“; Abschluss zeigt „Nicht in Ordnung“ mit Begründung des Servers und „Mangel #… angelegt“; der Mangel steht in der Mängelliste.
2. Pflichtpunkt leer lassen, „Entfällt“ ohne Begründung → Abschluss abgelehnt, Meldungen stehen am jeweiligen Punkt, Eingaben bleiben.
3. Zwischenstand in der App speichern → im Web sichtbar und umgekehrt; nach dem Abschluss ist er weg.
4. Offline: Checklisten-Liste aus dem Cache zeigt keinen Zwischenstand und keinen Namen.
5. „Mangel mit Foto“: Kamera öffnet sofort; mit vorgewähltem Fahrzeug genügen Auslösen und Speichern; Titel „Fahrzeug: RTW 1“; Foto hängt am Mangel.
6. Bezug „RTW 1“ mit offenem Mangel → „Bereits gemeldet“; „RTW 10“ zählt nicht mit.
7. QR-Code am Fahrzeug (Fuhrpark) bzw. am Gerät (MPG) wählt den Bezug vor, sofern es einen Eintrag in „Geräte & Fahrzeuge“ mit derselben Kennung gibt; fremde Server werden abgelehnt.
8. Dienstanweisung mit abgelaufener Lesefrist erscheint auf der Startseite und rot markiert; „Gelesen und verstanden“ bestätigt; bei inzwischen neuer Version (409) Hinweis und Neuladen.
9. Fristen-Erinnerung, Wochenübersicht und Lesefrist erscheinen als Benachrichtigung und im Posteingang „Hinweise“; im Web sind genau diese danach gelesen, unbekannte Arten bleiben ungelesen.
10. Übergabe als Nachtrag vom Papierbogen (im Web angelegt) zeigt in der App „Nachtrag vom Papierbogen · Ereignis … · erfasst …“.
11. Dieselben Schritte gegen einen Server 0.27: keine Abstürze, ausgeblendete Funktionen, Checklisten mit einem Tipp.

## 6. Store-Angaben

- Texte und „Neuerungen in 1.2“: [`STORE-METADATA.md`](STORE-METADATA.md).
- Data Safety (Play) und App Privacy (Apple) **vor** dem Produktions-Rollout ergänzen: Checklisten-Ergebnisse und Zwischenstand (nutzergenerierte Inhalte) sowie Lesebestätigungen (App-Interaktion) kommen dazu.
- Datenschutzerklärung: [`PRIVACY-POLICY.md`](PRIVACY-POLICY.md) (Stand 9. November 2026) und die Datenschutzseite der App sind auf 1.2 abgeglichen.
- Screenshots für Checklisten-Lauf und Lesepflicht vom Review-Server mit 0.28 aufnehmen; die Demo-Profile enthalten diese Daten nicht.

## 7. Freigabekriterium

1.2 geht je Plattform in Produktion, wenn

- die Gates aus Abschnitt 2 auf dem Release-Head grün sind,
- die Upgrade-Matrix und die manuellen Prüfungen gegen 0.27 und 0.28 auf echten Geräten bestanden sind,
- Store-Texte, Datenschutzangaben und Screenshots dem tatsächlichen Build entsprechen.
