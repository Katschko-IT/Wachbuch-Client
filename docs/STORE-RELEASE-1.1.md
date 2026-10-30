# Store Release 1.1 – Abnahmeplan

Stand: 30. Oktober 2026  
Geplanter Build: **1.1.0+13**

Dieses Dokument ergänzt [`STORE-RELEASE-1.0.md`](STORE-RELEASE-1.0.md). Identitäten, Signierung, Store-Konten und die manuellen Schritte in App Store Connect und Play Console gelten unverändert weiter; hier steht nur, was für 1.1 neu oder anders ist.

## 1. Inhalt und Paarung

- **Server:** mindestens **0.25.0** (Paginierung `active=1`/`limit`/`next`, Kaffeekasse `scope`), Monatsbeitrag der Kaffeekasse ab **0.26.0**, empfohlen **0.26.1**.
- **Neu gegenüber 1.0.0+12:** Offline-Vertrag mit 24 h und Rollenausschluss, zentrale Abmeldung bei 401/403, Sperre der Chat-Identität beim Abmelden, Designsystem „Wachbuch Klar 2“, Übergaben anlegen, Termine anlegen (Schichtleitung/Admin), Kaffeekasse mit Monatsbeitrag und „Ich habe bezahlt“, Mängel bearbeiten und seitenweise laden, lokale Erinnerung zur Fahrzeugfreigabe, Kopplung am Wachenterminal.
- **Build-Nummer:** 13 muss größer sein als jede jemals in Play Console oder App Store Connect hochgeladene Build-Nummer. Vor dem ersten Upload in beiden Konsolen prüfen.
- **Secure Storage:** bleibt auf `flutter_secure_storage` 10.x (10.3.4). Keine neue Speicher-Migration; `migrateOnAlgorithmChange` und `migrateWithBackup` bleiben unverändert (siehe [`SECURE-STORAGE-MIGRATION-1.0.md`](SECURE-STORAGE-MIGRATION-1.0.md)). Kein direkter Sprung auf 11.x.
- **Android-Berechtigungen:** gegenüber dem 1.0-Store-Build kommen `POST_NOTIFICATIONS` und `VIBRATE` (lokale Erinnerungen) dazu. Die CI prüft die vollständige Liste: `ACCESS_COARSE_LOCATION`, `ACCESS_NETWORK_STATE`, `CAMERA`, `INTERNET`, `POST_NOTIFICATIONS`, `VIBRATE` plus die paketgebundene Receiver-Berechtigung.

## 2. Automatische Gates

Wie 1.0 (Abschnitt 2 dort). Für den 1.1-PR sind verbindlich:

- **Flutter CI**: Job `test` (`flutter pub get`, unverändertes `pubspec.lock`, `flutter gen-l10n`, `flutter analyze` ohne Befund inklusive `integration_test/`, vollständige Test-Suite) und Job `android` (Internal-APKs, Production-AAB, Lint, Identitäts-/Berechtigungs-/SDK-/Signatur-/Größenprüfung).
- **Dependency Security** (OSV).
- **iOS CI** (`ios.yml`): Der selbst gehostete Mac-Runner war zuletzt nicht erreichbar. Gemergt wird erst, wenn `ios.yml` auf dem PR-Head grün ist – oder wenn der Owner für das Client-Repo ausdrücklich darauf verzichtet; dann steht dieser Verzicht im PR. `permission_handler` 13 ist auf iOS durch `main` (67e36f3) schon belegt; offen ist nur die zusammengeführte Kombination.

## 3. Rollout

1. PR auf `main` mit grünen Gates mergen.
2. **Android zuerst:** Workflow **Android Signed Release** auf `main` mit `1.1.0` / `13`.
3. Play Console: interner Test → geschlossener Test → Produktion als gestaffelter Rollout.
4. **iOS:** Workflow **TestFlight** mit `1.1.0` / `13` erst, wenn der Mac-Runner repariert und `ios.yml` auf `main` grün ist. Danach TestFlight → App Store.
5. Tag `v1.1.0` auf den Release-Commit.

### Erzwungenes Update für installierte 1.0-Apps

Wer 1.0 nicht aktualisiert, behält den alten Offline-Cache. 1.0 fragt beim Start `/api/v1/check-update/` ab und blockiert, wenn der Server ein Update verlangt. Sobald der Build auf einer Plattform **live** ist, legen Betreiber im Django-Admin einen `AppVersion`-Eintrag an:

| Feld | Android | iOS |
| --- | --- | --- |
| `platform` | `android` | `ios` |
| `version` | `1.1.0` | `1.1.0` |
| `min_required_version` | `1.1.0` | `1.1.0` |
| `download_url` | Play-Store-Link | App-Store-Link |
| `is_active` | an | an |

Für iOS erst, wenn ein TestFlight- bzw. App-Store-Build existiert – sonst sperrt der Dialog iPhones ohne verfügbares Update aus.

## 4. Upgrade-Matrix auf echten Geräten

| Ausgangsstand | Ziel | Erwartung |
| --- | --- | --- |
| 1.0.0+12 (Android) | 1.1.0+13 | Sitzung bleibt angemeldet; der alte Cache ohne `schema_version` wird beim ersten `/me/` gelöscht und neu nach Vertrag geschrieben. |
| 1.0.0+12 (iOS) | 1.1.0+13 | wie Android. |
| Build mit Storage 9.x (≤ 1.0.0+11) | 1.1.0+13 | derselbe Pfad wie 9.x → 1.0.0+12 (`SECURE-STORAGE-MIGRATION-1.0.md`), danach wie oben. |

## 5. Manuelle Prüfungen

Zusätzlich zu den Review-Testfällen aus 1.0 (Abschnitt 10 dort):

1. Kaltstart ohne Netz zeigt keine Wachendaten (nur Offline-Hinweis bzw. Anmeldung).
2. Ein Cache-Eintrag älter als 24 h wird nicht verwendet (Geräteuhr +25 h, Netz aus).
3. Master-Admin, Kassenwart und Auditor haben offline keine Daten.
4. Nach Abmelden fragt der Chat erneut nach der Passphrase.
5. Token im Web widerrufen → die App meldet beim nächsten Laden automatisch ab.
6. Konto ohne aktive Mitgliedschaft (403) → Hinweis „Für dieses Konto gibt es keinen aktiven Wachenzugang…“.
7. 1.0.0+12 zeigt nach dem `AppVersion`-Eintrag den blockierenden Update-Dialog.
8. Mitglied: „Neue Übergabe“ sichtbar, kein Status, kein „Termin anlegen“; Auditor: keine Schreibaktionen, kein „Bearbeiten“ im Mangel.
9. Schichtleitung: Status „Erledigt“ entfernt die Übergabe aus der aktiven Liste; „Termin anlegen“ vorhanden.
10. Kaffeekasse mit Monatsbeitrag (Server ≥ 0.26.0): Monate, „Ich habe bezahlt“ genau einmal gebucht.
11. Foto über 5 MiB wird vor dem Senden abgelehnt; hinter nginx mit kleinerem `client_max_body_size` erscheint „Datei zu groß für den Server“.
12. Unbekannter Gerätestatus erscheint als „Status unbekannt“.
13. Optional: `integration_test/app_e2e_test.dart` im iOS-Simulator gegen einen Server ≥ 0.26.1 (README, Abschnitt „Ende-zu-Ende-Test“); daraus die Store-Screenshots.

## 6. Store-Angaben

- Texte, „Neuerungen in 1.1“ und Datenschutzangaben: [`STORE-METADATA.md`](STORE-METADATA.md).
- Data Safety (Play) und App Privacy (Apple) **vor** dem Produktions-Rollout aktualisieren: Selbstmeldung der Kaffeekasse und Gelesen-Status persönlicher Hinweise kommen dazu.
- Screenshots aus dem 1.1-Build mit Demo-Daten neu aufnehmen; Klar 2 hat das Erscheinungsbild geändert.
- Datenschutzerklärung: [`PRIVACY-POLICY.md`](PRIVACY-POLICY.md) (Stand 30. Oktober 2026) und die Datenschutzseite der App sind auf 1.1 abgeglichen.

## 7. Freigabekriterium

1.1 geht je Plattform in Produktion, wenn

- die Gates aus Abschnitt 2 auf dem Release-Head grün sind (iOS: siehe dort),
- die Upgrade-Matrix und die manuellen Prüfungen auf echten Geräten bestanden sind,
- Store-Texte, Datenschutzangaben und Screenshots dem tatsächlichen Build entsprechen,
- der `AppVersion`-Eintrag für die Plattform erst nach Live-Schaltung gesetzt wird.
