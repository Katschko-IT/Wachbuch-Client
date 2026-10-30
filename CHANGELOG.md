# Changelog

Alle wesentlichen Änderungen an Wachwerk Mobile werden hier dokumentiert.

## 1.1.0 – Releasedatum offen

Build `1.1.0+13`. Server mindestens **0.25.0** (Paginierung, `scope`); der
Monatsbeitrag der Kaffeekasse braucht **0.26.0**; empfohlen **0.26.1**.
Freigabeplan: [`docs/STORE-RELEASE-1.1.md`](docs/STORE-RELEASE-1.1.md).

### Verhaltensänderungen gegenüber 1.0

- Ein Kaltstart ohne Netz zeigt keine Wachendaten mehr (Offline-Vertrag §5):
  Der Offline-Lesecache wird erst gelesen, nachdem die Sitzung online
  bestätigt wurde. Master-Admin, Kassenwart und Auditor bekommen gar keinen
  Offline-Cache. Ein Cache aus 1.0 ohne `schema_version` wird beim ersten
  `/me/` gelöscht.
- Nach dem Update kann ein persönlicher Hinweis einmal erneut erscheinen:
  „schon angezeigt“ gilt jetzt pro Benutzer statt pro Token.
- Ein unbekannter oder fehlender Geräte-/Fahrzeugstatus heißt „Status
  unbekannt“ statt „Einsatzklar“.
- Die Auswertung zeigt keine Mängel je Person mehr, auch nicht für ältere
  Server (< 0.26.1), die `defects_by_owner` noch liefern.
- Der Posteingang zeigt nur bekannte Hinweisarten (`vehicle_ready`,
  `coffee_due`) als Benachrichtigung und meldet nur diese als gelesen;
  andere Arten bleiben ungelesen auf dem Server und im Web-Posteingang.

### Neu

- Übergaben in der App anlegen (Titel, Text, Bereich, Dringlichkeit) für
  alle Inhaltsrollen (nicht Auditor). Schichtleitung und Admin setzen den
  Status im Detail; erledigte Übergaben verschwinden aus der aktiven Liste.
- Kaffeekasse mit Monatsbeitrag (Server ab 0.26.0): eigener Stand mit
  offenen und bezahlten Monaten, „Ich habe bezahlt“ (bar, Überweisung,
  PayPal; `POST /api/v1/kaffeekasse/bezahlt/`) und Zahlungswege mit IBAN zum
  Kopieren. Zahlungslinks werden nur als https geöffnet. Ohne Monatsbeitrag
  „Kassenstand der Wache“ bzw. „Mein Saldo“ je nach `scope`.
- Kalender: Schichtleitung und Admin legen Termine an.
- Mängel bearbeiten (Beschreibung, Ort/Gerät, Dringlichkeit, Frist) für alle
  Inhaltsrollen; „Erledigt“ bleibt Schichtleitung und Admin vorbehalten.
- Mängel seitenweise (`active=1`, `limit`, `next`) mit „Mehr laden“ und
  „Erledigte anzeigen“. Übergaben folgen den `next`-Seiten des Servers, aber
  nur auf demselben Server und höchstens zehn Seiten.
- Anhänge ohne Bildtyp (z. B. PDF) zeigen „Vorschau nicht verfügbar“.
- Neue Freitextformulare (Übergabe, Termin, Mangel bearbeiten) erinnern:
  „Keine Patienten- oder Einsatzdaten eintragen.“
- Wache ohne Internet: Ein Verbindungs-QR mit `pin=sha256/…` hinterlegt den
  Fingerabdruck eines lokalen Serverzertifikats (z. B. Raspberry Pi mit eigenem
  WLAN). Die App vertraut dann genau diesem Zertifikat für diesen Server.
- Kopplung am Wachenterminal: Ein QR mit `pair=…` meldet die App ohne Passwort
  mit dem eigenen Konto an (Server ab 0.24.0, `POST /api/v1/token/kopplung/`).
- Erinnerung für die Besatzung, wenn ein Fahrzeug nach der Desinfektion
  freigegeben werden kann (Server ab 0.24.0). Die App plant eine lokale
  Benachrichtigung zur Sperrzeit (`locked_until`) und zeigt neue Hinweise aus
  dem persönlichen Posteingang. Freigeben muss die Besatzung selbst; der
  Server gibt Fahrzeuge nicht automatisch frei. Neue Android-Berechtigungen:
  `POST_NOTIFICATIONS`, `VIBRATE`. Nativer Push über APNs/FCM ist
  serverseitig vorbereitet (`docs/PUSH-RELAY.md` im Server-Repository).
- iOS: Hinweistext für den Zugriff auf das lokale Netzwerk
  (`NSLocalNetworkUsageDescription`).

### Datenschutz und Sicherheit (Review 2026-10-24)

- Abmelden und Serverwechsel sperren die entschlüsselte Chat-Identität.
- 401 und 403 „Kein aktiver Wachenzugang“ melden app-weit ab (Token,
  Krypto, Offline-Cache); fehlende Mitgliedschaft mit eigenem Hinweis. Das
  gilt auch für die neuen Schreibaufrufe. Der Erinnerungsdienst schluckt 401
  nicht mehr.
- Offline-Cache nach `docs/CLIENT-OFFLINE-CONTRACT.md` des Servers: nur
  eigene Mitgliedschaft, Checklisten und Übergabeliste ohne Freitext (nur die
  erste Seite), höchstens 24 h alt, nicht für `admin`/`cashier`/`auditor`,
  lesbar erst nach online bestätigter Sitzung. Kaffeekasse, Übergabe-Details,
  Mängel, Termine und Anhänge werden nicht gespeichert.
- Schreibaufrufe werden nicht automatisch wiederholt: Übergabe anlegen,
  Status setzen, Termin anlegen, „Ich habe bezahlt“ und Mangel bearbeiten
  (dort hätte eine Wiederholung Mangel-Ereignisse und Audit-Einträge
  verdoppelt).
- Rechte wie auf dem Server (`lib/state/station_roles.dart`): Asset-Status,
  „Mangel erledigt“, Übergabe-Status, Termin anlegen und Rückgabe fremder
  Ausleihen nur für Schichtleitung/Admin (`WRITE_ROLES`); Übergabe anlegen und
  Mangel bearbeiten nur für Inhaltsrollen (`CONTENT_ROLES`).
- Hinweise werden nach dem Anzeigen als gelesen gemeldet.
- Mängelfotos: eine Grenze von 5 MiB je Datei wie auf dem Server, in der
  Oberfläche und im API-Aufruf (die Oberfläche prüfte zuvor noch 2 MiB).
  Fotos gehen base64-kodiert im JSON; hinter einem Proxy kann die wirksame
  Grenze daher niedriger liegen.
- 413/415/429 ohne JSON-Körper (z. B. von nginx) mit verständlicher Meldung
  („Datei zu groß für den Server“, „Dateityp nicht unterstützt“, bei 429 inkl.
  `Retry-After`).
- Datenschutzseite der App und `docs/PRIVACY-POLICY.md` beschreiben Cache,
  Abmeldung, neue Übertragungen und lokale Benachrichtigungen.

### Erscheinungsbild

- Designsystem „Wachbuch Klar 2“ (gleich mit der Web-PWA):
  - Tokens hell/dunkel als ThemeExtension `WachbuchColors`; Namen wie im Web
    (`brandDeep` und `brandHover` waren vertauscht).
  - Hausschrift Atkinson Hyperlegible Next (OFL), tabellarische Ziffern für
    Beträge und Uhrzeiten.
  - Statusbedeutung einheitlich: dringend = danger, offen = info,
    in Arbeit = warning, wartend = neutral, erledigt = success.
  - Gemeinsame Widgets `EmptyState` und `SectionTitle`; Warnmarkierung als
    einziges Markenelement oben in der Kopfleiste.
- Die App heißt jetzt **Wachwerk** wie der Server: App-Name auf dem
  Homescreen (Android und iOS), Texte und Hinweise zu Berechtigungen,
  Datenschutzseite, Landingpage und Doku. Bundle-ID, Paketname,
  Deep-Link-Schema (`wachbuch://`), gespeicherte Anmeldungen und
  Store-Schlüsselwort „wachbuch“ bleiben unverändert, damit bestehende
  Installationen und QR-Codes weiter funktionieren.
- Neues App-Icon statt des Flutter-Standardicons: blaues Feld im Wachwerk-Blau
  (#0D4693) mit weißem kursivem „W“ – iOS, Android (adaptiv inkl. Themen-Icon ab
  Android 13, abgerundet für ältere Versionen) und Favicon der Landingpage.
  Erzeugt mit `tool/make_app_icons.py`; die Glyphe stammt aus Inter Display
  SemiBold Italic (SIL Open Font License 1.1).
- Startbildschirm in Wachwerk-Blau mit weißem „W“ statt des weißen
  Flutter-Standards (Android bis 11 per `launch_background.xml`, ab Android 12
  per `values-v31`, iOS per `LaunchScreen.storyboard`). Die alte
  `flutter_native_splash.yaml` verwies auf ein fehlendes Bild und war nie
  wirksam; sie enthält jetzt dieselben Werte.
- High-Contrast-Emergency-Themes sind an `MaterialApp` verdrahtet
  (`highContrastTheme` / `highContrastDarkTheme`).

### Server-Abgleich (Review 2026-10-22)

- Kaffeekasse liest die echten Serverfelder `balance_euros`, `results`,
  `amount_euros` und `reason` (zuvor immer „0,00 €“ und keine Buchungen).
- Kassenstand zeigte statt des Währungssymbols einen Funktionsnamen
  (`Closure: …`); behoben.
- Checklisten übernehmen Prüfpunkte, die der Server als Texte liefert, und
  leiten „erledigt“ aus `last_completed_at` und Turnus ab; der Name der
  abschließenden Person wird angezeigt.
- Ein Abschluss ersetzt die Karte nicht mehr durch eine leere Liste,
  sondern ergänzt Zeitpunkt, Turnus und nächste Fälligkeit.
- Modul-Chips zeigen Wachenchat, Pinnwand, Feiertage und Wetter mit Namen
  und blenden Zusatzangaben wie `holiday_state` aus.
- Logout ruft `DELETE /api/v1/token/` best-effort auf und räumt den lokalen
  Speicher danach in jedem Fall. Demo-Sitzungen bleiben ohne Netzaufruf.
- Die Vibe-P0-P3-Änderungen (nicht existierendes `geolocator 14.1.0`,
  unwirksames Certificate Pinning) sind von `main` zurückgenommen.

### Abhängigkeiten

- Flutter 3.47.8; mobile_scanner 7.4.2, package_info_plus 10.2.2,
  permission_handler 13.0.2 (Android kompiliert dafür gegen API 37;
  `targetSdk` bleibt beim Flutter-Standard), app_links, geolocator,
  image_picker, shared_preferences, url_launcher, flutter_secure_storage
  10.3.4; Gradle 9.8.2, Android Gradle Plugin 9.4.1, Kotlin 2.4.21; GitHub
  Actions mit SHA-Pin.
- Bewusst nicht angehoben: flutter_secure_storage 11 (gestufte Migration, siehe
  `docs/SECURE-STORAGE-MIGRATION-1.0.md`; 1.1 bleibt auf 10.x ohne neue
  Speicher-Migration) und connectivity_plus 7.3.2 (dbus-Konflikt mit
  geolocator).

## 1.0.0 – Store-Release-Kandidat

### Wachalltag

- Reale Server-Parität für Übergaben, Quittierungen, Mängel, Mängelfotos,
  Geräte-/Fahrzeugstatus, Inventar/Pools, wiederkehrende Checklisten und
  Auswertungen.
- Übergaben können direkt als Mangel übernommen werden.
- Demo-Profile für Rettungsdienst, Feuerwehr, Freiwillige Feuerwehr und Polizei
  spiegeln die produktiven Kernabläufe ohne externen Demo-Server.
- Verschlüsselter, server- und tokengebundener Offline-Lesecache mit sauberer
  Bereinigung bei Logout und Serverwechsel.

### Sicherheit und Robustheit

- Strukturierter API-Fehlervertrag inklusive MFA-Codes und Correlation-ID.
- Schreibende, nicht idempotente API-Aufrufe werden nicht automatisch
  wiederholt.
- Mängelfotos werden auf Dateityp, Inhalt, Dateigröße und Serverkontingente
  begrenzt.
- Cold-Start-/Deep-Link-Sessionwechsel bereinigen alte Credentials und Caches;
  ein Link zum bereits konfigurierten Server widerruft die Sitzung nicht.

### Store-Release

- Version `1.0.0+11`.
- Production-ID Android: `de.wachbuch.mobile`.
- Bundle-ID iOS/iPadOS: `de.wachbuch.wachbuchMobile`.
- Android Signed Release mit echtem Upload-Key, API-36-, Permission-,
  Signatur-, Lint-, Größen- und SBOM-Gates.
- iOS-/TestFlight-Gates für Xcode 26+, iOS-SDK 26+, Bundle-/Build-Metadaten,
  Provisioning Profile, Codesignatur, Privacy-Manifeste und App-Validierung vor
  Upload.
- Datenschutzinformationen bereits vor Login in der App erreichbar.
- Öffentliche Datenschutz-/Support-Dokumente, Store-Metadaten, Review-Hinweise
  und verbindliche 1.0-Abnahmecheckliste ergänzt.

## Unreleased – Landingpage & Behörden-Demo

### CI

- Android-/Dependency-Workflows auf **JDK 21** (AGP 9.3 Lint braucht
  `List.removeLast()`); `BidiSpoofing` in `lint.xml` abgesichert.

### Neu

- Statische Landingpage unter `landing/` mit Projektvorstellung und interaktivem
  Demo-Modus für Rettungsdienst, Feuerwehr und Polizei.
- Webapp unter `landing/app/` im Landingpage-Design: Organisationswahl, Übersicht,
  Übergaben, Mängel-Workflow, Statusboard, Gerätepools, Quittierung, Kalender,
  Kaffeekasse, Checklisten; Profile inkl. Freiwillige Feuerwehr.
- Fachfahrplan `docs/FAHRPLAN-BEHOERDEN.md` (Phasen A–I, Server-/Mobile-Pfad).
- Offline-Demo in der App: Startbildschirm → „Demo-Modus ausprobieren“ mit
  Organisationsprofilen (RD, Feuerwehr, FFW, Polizei) und Muster-Übergaben,
  Kalender, Kaffeekasse und Checklisten.
- Flutter Phase A–D (Demo): Modelle `Defect` / `StationAsset` / `HandoverAck`,
  Contract `docs/SCHEMA-WACHALLTAG.md`, Mängel-Screen, Statusboard auf der
  Übersicht, Quittierung im Übergabe-Detail.
- Flutter HTTP für `defects` / `assets` / `inventory` / `acks` verdrahtet
  (404 = Modul nicht verfügbar); Demo-API + Inventar-Checkout; Checklisten mit
  `interval` / `due_next` / `overdue`.
- Webapp: Demo-Anhänge (Phase E), Fälligkeitsbereich Checklisten (F),
  Auswertung (I), Inventar bereits unter Geräte (G).
- Gelbes Demo-Banner in der App-Shell, analog zum Server-Demo-Modus.

## Unreleased – Module API (Kalender, Kaffeekasse, Checklisten)

### Neu

- Doku-Sync: Server-Versionspaarung dokumentiert
- `GET /api/v1/kalender/` – Wachenkalender mit Terminen (Titel, Beschreibung, Start/Ende, Ganztag, Ort).
- `GET /api/v1/kaffeekasse/` – Kassenstand, Zahlungshinweise und letzte Buchungen (Ledger).
- `GET /api/v1/checklisten/` – Checklisten mit Punkten und Abhak-Status.
- `POST /api/v1/checklisten/{id}/abschluss/` – Checklisten serverseitig abschließen (append-only) mit optimistischer UI und Rollback bei Fehler.
- Getypte Datenmodelle für die drei neuen Bereiche mit defensiver JSON-Serialisierung.
- Schnellzugriff-Kacheln auf dem Übersicht-Dashboard, die nur für aktivierte Module erscheinen und per Navigator die jeweiligen Screens öffnen.
- Responsive Material-3-Screens mit Ladefehler-/Leerzustand, `RefreshIndicator` und Fehler-Banner.
- Bottom-Navigation (Phone) und NavigationRail (Tablet) bleiben erhalten; die neuen Screens werden zusätzlich über tappbare Kacheln erreichbar.

### Tests

- Modell-Tests (JSON-Serialisierung, Alias-Felder, fehlerhafte Eingaben).
- API-Service-Tests mit Mock-Responses für alle vier Endpunkte.
- Widget-Tests für die drei neuen Screens inkl. Abschluss- und Fehlerrollback-Flow.
- Dashboard-Test für die Modul-Kacheln und die Navigation in die neuen Screens.

## Unreleased – Android Release Hardening

### Sicherheit und Auslieferung

- Interne und produktive Android-Varianten besitzen getrennte Paket-IDs, Namen und Deep-Link-Schemas.
- Produktionsbuilds fallen nicht mehr auf den Android-Debug-Key zurück.
- Produktive Signierung wird ausschließlich aus privater lokaler Konfiguration oder geschützten CI-Secrets geladen.
- Cloud-Backup und Geräteübertragung sind für sämtliche App-Daten ausgeschlossen.
- Deep-Links prüfen jetzt exakten Host, leeren Pfad, genau einen URL-Parameter und lehnen eingebettete Zugangsdaten ab.
- R8-Minifizierung, Resource Shrinking, ABI-Splits und Dart-Obfuskation sind für Release-Builds aktiviert.

### Qualität und Nachvollziehbarkeit

- Android-Lint, Signatur-, Paket-ID-, Debbugable- und Größenprüfungen wurden als CI-Gates ergänzt.
- CI erzeugt SHA-256-Hashes, Obfuskationssymbole und Flutter-/Android-Abhängigkeitsberichte.
- Geschützter Workflow für signierte AAB- und APK-Artefakte mit temporärem Upload-Keystore ergänzt.
- Dauerhafte Android-10/10-Roadmap sowie Installations- und Play-Store-Dokumentation ergänzt.

## 0.5.1 – 2026-08-02

### Sicherheit und Robustheit

- Deep-Links im laufenden Betrieb fragen nach, bevor eine aktive Sitzung auf einen anderen Server umgestellt wird.
- Gespeicherte Server-URLs werden beim Start erneut gegen die HTTPS-Regeln geprüft.
- App-Tokens speichern und prüfen `expires_at`; abgelaufene Sitzungen landen auf dem Login mit Hinweis.
- MFA-Antworten werden über den API-Code `mfa_required` erkannt, nicht nur über den Text.
- Discovery akzeptiert nur Antworten, die wie ein Wachbuch-`/api/v1/`-Root aussehen.
- Standort für das Solar-Theme wird nicht mehr ungefragt angefordert (System-Theme-Fallback).

### Optimierungen

- Übersicht und Übergaben laden parallel (`Future.wait`).
- Tab-Wechsel behält Filterzustand (`IndexedStack`).
- Überlappende Reloads werden per Generationszähler verworfen.
- Modul-Chips zeigen deutsche Bezeichnungen statt API-Schlüssel.
- Passwort-/Token-Felder werden nach erfolgreicher Anmeldung geleert.

## 0.5.0 – 2026-08-02

### Design und Lesbarkeit

- Durchgängiges, deterministisches Weiß-Blau-Designsystem für helles und dunkles Erscheinungsbild.
- Lesbare Typografie mit mindestens 14 sp für Hinweise, Metadaten und Statusbeschriftungen.
- Neu gestaltete Übersicht mit Wachen-Header und drei schnell erfassbaren Statuskarten.
- Übergabekarten mit klarer Prioritätsmarkierung, größeren Abständen und kontrastgesicherten Chips.
- Strukturierte Suche und Filter mit größeren Touch-Zielen und eindeutiger visueller Hierarchie.
- Kontrastreiche Fehlerbanner mit Icon und Screenreader-Live-Region auf allen betroffenen Screens.
- Lange Wachennamen werden in der App-Bar kontrolliert gekürzt; Karten bleiben bei 200 % Textskalierung überlauffrei.

### Qualität

- Reale Smartphone-Screenshots vor und nach der Überarbeitung mit Vision geprüft.
- Theme-, Kontrast-, Semantik-, Dashboard- und Lesbarkeits-Regressionstests ergänzt.
- Offizielle Flutter-Material-3- und Accessibility-Muster sowie offene Designsysteme als Referenz ausgewertet.

## 0.4.0 – 2026-08-02

### Neu

- Material-3-Suche über Titel, Kategorie, Status und Priorität der aktiven Übergaben.
- Kombinierbare Status- und Prioritätsfilter mit einsatzgerechter Reihenfolge „Dringend → Wichtig → Normal“.
- Lokalisierte, farbige Chips statt technischer API-Werte.
- Ergebniszähler und eigener Leerzustand für Filter ohne Treffer.
- Antippbare Übergabekarten mit Detail-Bottom-Sheet für Beschreibung, Autor, Änderungszeit und Version.
- Dashboard-Zusammenfassung für offene, laufende und dringende Übergaben.

### Qualität

- Filterlogik als reine, defensiv gegen fehlende Felder getestete Funktion ausgelagert.
- API-Vertrag für `GET /api/v1/handovers/{id}/` durch Regressionstest abgesichert.
- Smartphone- und Tablet-Layouts für die neuen Karten und Filter getestet.
- Detailaufrufe bleiben auch bei UI-Rebuilds auf genau einen HTTP-Request begrenzt.
- Aktive Filter bleiben nach einem Daten-Reload sichtbar und entfernbar.
- Unerwartete optionale API-Feldtypen führen nicht zum Absturz der Karten oder Detailansicht.
- Übergabekarten passen ihre Höhe bis mindestens 200 % Textskalierung ohne Überlauf an.

## 0.3.0 – 2026-08-02

### Neu

- Responsives Material-3-Layout für Smartphone und Tablet durch Regressionstests abgesichert.
- Automatischer Wechsel zwischen hellem und dunklem Design anhand lokal berechnetem Sonnenaufgang und Sonnenuntergang.
- Ungefährer Vordergrundstandort wird ausschließlich auf dem Gerät verarbeitet; keine externe Wetter- oder Standort-API.
- Fallback auf das Systemdesign, wenn Standortdienste deaktiviert oder die Berechtigung verweigert sind.
- Automatische Neuberechnung beim nächsten Sonnenwechsel und nach Rückkehr in die App.
- Vollständige Deep-Link-Unterstützung für `wachbuch://connect?url=…` unter Android und iOS.

### Sicherheit

- Ein Serverwechsel über Deep-Link löscht den alten App-Token, bevor die neue Adresse übernommen wird.
- Release-Builds lehnen unsichere HTTP-Server ab; HTTP bleibt nur in Debug-Builds explizit möglich.
- Temporäre und langlebige HTTP-Clients werden deterministisch geschlossen.

## 0.2.1 – 2026-08-02

### Geändert

- Flutter-Projekt vollständig in das eigenständige Client-Repository übernommen.
- API-Aufrufe erhalten ein konfigurierbares Zeitlimit von standardmäßig 20 Sekunden.
- Verständliche Meldungen für Netzwerkfehler, Zeitüberschreitungen, Reverse-Proxy-Fehler und ungültige Serverantworten.
- Lifecycle-Race behoben: späte API-Antworten lösen nach dem Schließen eines Screens kein `setState()` mehr aus.
- QR- und Serveradressen lehnen fremde Schemes, unvollständige Wachbuch-Links und beschädigte JSON-Payloads sauber ab.

### Tests

- API-Vertrag: Discovery, Token-Anmeldung, Auth-Header und Fehlerpfade.
- Secure Storage und Shared Preferences.
- Startflow, Formvalidierung und responsive Hauptnavigation.
- Regressionstest für späte API-Fehler nach Widget-Dispose.

### Android

- Installierbare Sideload-APK für Android 7.0 und neuer.
- Release-Build bleibt für lokale/CI-Verteilung mit Debug-Key signiert; Play-Store-Veröffentlichung benötigt einen eigenen Upload-Key.
