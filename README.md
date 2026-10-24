# Wachbuch Client (AGPL)

Open-Source-Begleit-App für das selbst gehostete **[Wachbuch](https://github.com/Katschko-IT/Rettungswache-Wachbuch)** auf iOS und Android.

| | |
| --- | --- |
| **Client** | https://github.com/Katschko-IT/Wachbuch-Client |
| **Server** | https://github.com/Katschko-IT/Rettungswache-Wachbuch |
| **Lizenz** | AGPL-3.0-or-later |
| **API** | `/api/v1/` · Token-Auth |
| **App-Version** | `1.0.0+12` |
| **Produktiv-Paarung** | Server `0.24.x` |
| **E2E-Abnahme** | [docs/E2E-WACHALLTAG.md](docs/E2E-WACHALLTAG.md) |
| **Store-Release** | [docs/STORE-RELEASE-1.0.md](docs/STORE-RELEASE-1.0.md) |
| **Secure-Storage-Migration** | [docs/SECURE-STORAGE-MIGRATION-1.0.md](docs/SECURE-STORAGE-MIGRATION-1.0.md) |
| **Roadmap** | [ROADMAP.md](ROADMAP.md) |

## Quelle der Wahrheit

Dieses Repository ist die **kanonische Quelle** für den Flutter-/iOS-/Android-Client. Der historische Ordner `clients/wachbuch-mobile/` im Server-Repository darf diesen Stand nicht überschreiben.

## Was 1.0 kann

- Serveradresse oder QR verbinden; App-Token sicher in Keychain/Keystore speichern
- Android Secure Storage 10.x mit RSA-OAEP/SHA-256 + AES-GCM und crash-resistenter Migration aus 9.x
- strukturierter API-Fehlervertrag mit `code`, `message` und `correlation_id`
- MFA-Fehler `mfa_required` und `mfa_setup_required` sauber behandeln
- Übergaben suchen/filtern, Details öffnen und pro Benutzer quittieren
- Übergabe direkt als echten Mangel übernehmen
- Mängel anlegen, priorisieren, zuordnen, terminieren und Status ändern
- authentifizierte Mängelfotos aus Kamera/Mediathek hoch- und herunterladen
- Foto-Schutz: JPEG/PNG/WebP, 2 MiB je Datei; aktueller Server normalisiert gespeicherte Mängelfotos zusätzlich metadata-frei
- Fahrzeug-/Gerätestatus anzeigen und bei berechtigter Rolle ändern
- Schlüssel-/Poolgeräte ausgeben und zurückgeben
- wiederkehrende Checklisten mit täglicher/wöchentlicher/monatlicher Fälligkeit
- Auswertung für offene/überfällige Mängel, Checks, Einsatzklarquote, Pools und Quittierungen
- token- und servergebundener verschlüsselter Offline-Lesecache nach dem Server-Vertrag
  `docs/CLIENT-OFFLINE-CONTRACT.md`: nur eigene Mitgliedschaft, Checklisten und
  Übergabeliste (ohne Freitext), höchstens 24 h alt, nicht für `admin`, `cashier`,
  `auditor`, lesbar erst nach online bestätigter Sitzung
- Offline-Fallback nur bei echten Netzwerkfehlern; 401/403 werden nie durch Cache verdeckt
- Demo-Profile für Rettungsdienst, Feuerwehr, Freiwillige Feuerwehr und Polizei
- Phone: Bottom-Navigation · Tablet: NavigationRail + Grid
- Material Design 3, Dark/Light und große Textskalierung
- Deutsch/Englisch für produktive Wachalltag-Oberflächen
- direkt vor der Anmeldung erreichbare Datenschutzinformationen für Store-Compliance

## Produktgrenze

Wachbuch ist ein Werkzeug für den **Stations-/Wachalltag**. Nicht Teil des Modells sind insbesondere Patienten-, ePCR-, Einsatz-, Alarmierungs-, ELS-, Personalakten- oder vergleichbare sensible Fachdaten. Wachbuch ist keine offizielle Behörden-App und kein Notrufsystem.

## Landingpage & Web-Demo

```bash
cd landing && python3 -m http.server 4173
# Landing → http://127.0.0.1:4173/
# Webapp  → http://127.0.0.1:4173/app/
```

Die Demo dient als Produkt-/UX-Vorschau. Die entsprechenden Kernfunktionen Mängel, Geräte, Inventar, Quittierungen, wiederkehrende Checks, Fotos und Auswertung besitzen in `1.0` reale Server-Endpunkte.

## Lokaler Start

```bash
git clone https://github.com/Katschko-IT/Wachbuch-Client.git
cd Wachbuch-Client
flutter pub get
flutter test
flutter run --flavor internal
```

Auf iOS:

```bash
flutter pub get
flutter build ios --simulator --debug
```

## Android Internal

Die interne Variante besitzt die separate Paket-ID `de.wachbuch.mobile.internal` und kann parallel zur Produktions-App installiert werden:

```bash
./scripts/build-apk.sh
```

## Android Production

Ein Produktionsbuild benötigt einen eigenen Upload-Key und fällt niemals auf einen Debug-Key zurück:

```bash
cp android/key.properties.example android/key.properties
BUILD_NAME=1.0.0 BUILD_NUMBER=12 bash scripts/build-aab.sh
```

Der Release-Workflow erzeugt zusätzlich Hashes, Zertifikatsberichte, Obfuskationssymbole und eine CycloneDX-SBOM. Store-Builds werden ausschließlich aus `main` erzeugt und müssen exakt zur Version in `pubspec.yaml` passen.

## Server-Kopplung

Die Modelle und Tests orientieren sich an den Antwortformen von `core/api` im
Server-Repository (abgeglichen im Review vom 22. Oktober 2026: Kaffeekasse,
Checklisten, Modulschalter). Neue Felder werden zuerst serverseitig dokumentiert
und dann im Client mit einem Test der echten Antwortform übernommen.

Der Vertrag liegt im Server-Repository unter `docs/API.md`, `docs/CLIENT.md` und `docs/openapi.yaml`. Die Kopplung erfolgt ausschließlich über den versionierten API-Vertrag – nicht durch Kopieren eines Client-Quellbaums in das Server-Repository.

### Wache ohne Internet (Raspberry Pi mit eigenem WLAN)

Der Verbindungs-QR eines Pi-Servers lautet
`wachbuch://connect?url=https://10.42.0.1&pin=sha256/<Fingerabdruck>`. Die App
vertraut dann genau diesem Zertifikat für genau diesen Server
(`lib/api/server_trust.dart`); ein anderes Zertifikat wird abgelehnt, auf dem
Handy muss keine Zertifizierungsstelle installiert werden. Ein QR vom
Wachenterminal mit `pair=<Code>` meldet die App zusätzlich ohne Passwort an
(`POST /api/v1/token/kopplung/`, Code 120 s gültig und einmalig). Einrichtung
des Servers: `docs/PI-WACHENTERMINAL.md` im Server-Repository.

## Ende-zu-Ende-Test

`integration_test/app_e2e_test.dart` startet die echte `WachbuchApp` (echter
Secure Storage, echte HTTP-Aufrufe, keine Mocks; nur der lokale
Benachrichtigungsplaner ist still geschaltet) und bedient sie per
`WidgetTester` gegen einen laufenden Server:

- a–f: Serveradresse eingeben, als Mitglied anmelden, Übersicht, Übergabe
  anlegen (ohne Statusaktion), Mängel inkl. „Erledigte anzeigen“ (ohne
  „Erledigt“ für Mitglieder), Kalender/Kaffeekasse/Checklisten sofern als
  Modul aktiv, Abmelden; danach als Schichtleitung dieselbe Übergabe auf
  „erledigt“ setzen (gegen den Server geprüft).
- g: Token per `DELETE /api/v1/token/` widerrufen, beim Neuladen wechselt
  die App zur Anmeldung.
- HTTPS: Verbindungslink `wachbuch://connect?url=…&pin=sha256/…`; falscher
  Fingerabdruck wird abgelehnt, richtiger führt zur Anmeldung.

Server, Konten und Passwort kommen nur per `--dart-define` (nichts davon im
Repository); ohne `E2E_SERVER`/`E2E_PASSWORD` werden die Tests übersprungen.
HTTP ist nur im Debug-Build erlaubt, daher läuft der Test im Simulator:

```bash
xcrun simctl boot "iPhone 16"
flutter test integration_test -d <simulator-id> \
  --dart-define=E2E_SERVER=http://localhost:18090 \
  --dart-define=E2E_USER=app.mitglied \
  --dart-define=E2E_LEAD_USER=app.schicht \
  --dart-define=E2E_PASSWORD='<Passwort der Testkonten>' \
  --dart-define=E2E_HTTPS_SERVER=https://localhost:18443 \
  --dart-define=E2E_HTTPS_PIN=<SHA-256 des Leaf-Zertifikats, hex> \
  --dart-define=E2E_SCREENSHOT_DIR=/tmp/wachbuch-e2e
```

Der Pin ist der SHA-256 des DER-kodierten **Leaf**-Zertifikats (das prüft
`ServerTrust.certificateMatches`):

```bash
openssl s_client -connect localhost:18443 -servername localhost </dev/null \
  | openssl x509 -outform der | shasum -a 256
```

Caddys interne CA stellt Leaf-Zertifikate nur für 12 Stunden aus; der Pin
muss dann neu ermittelt werden. Optional: `E2E_STATION` (Wachenname in der
Übersicht, Standard „Rettungswache Musterstadt“) und `E2E_DEFECT_TITLE`
(erwarteter Mangel, Standard „E2E: Trage klemmt“). Mit `E2E_SCREENSHOT_DIR`
legt der Test PNGs von Anmeldung, Übersicht, Übergaben und Mängeln ab
(Suffix `-hell`/`-dunkel` nach Systemdarstellung, umschaltbar mit
`xcrun simctl ui <id> appearance dark`). Der Test legt bei jedem Lauf eine
Übergabe „E2E-App <Zeitstempel>“ an und setzt sie auf „erledigt“.

## Qualitätsgates

Vor Freigabe müssen mindestens bestehen:

- `flutter analyze`
- vollständige Flutter-Tests
- Android Internal APKs
- Production-AAB ohne Publishing-Credentials
- Android Lint
- Berechtigungs-/Signatur-/SDK-/Größen-Gates
- SBOM-Erzeugung
- iOS Simulator/Release-Build ohne Signierung
- Xcode 26+ und iOS-26-SDK+
- Dependency-Security
- reales Upgrade 9.x → 10.3.1 für Secure Storage vor breitem Rollout

Store-spezifisch siehe [docs/STORE-RELEASE-1.0.md](docs/STORE-RELEASE-1.0.md), [docs/STORE-METADATA.md](docs/STORE-METADATA.md), [docs/PRIVACY-POLICY.md](docs/PRIVACY-POLICY.md), [docs/PLAY-STORE.md](docs/PLAY-STORE.md), [docs/IOS-TESTFLIGHT.md](docs/IOS-TESTFLIGHT.md) und [docs/SECURE-STORAGE-MIGRATION-1.0.md](docs/SECURE-STORAGE-MIGRATION-1.0.md).

## Rechtliches

AGPL-3.0-or-later – siehe `LICENSE`.
