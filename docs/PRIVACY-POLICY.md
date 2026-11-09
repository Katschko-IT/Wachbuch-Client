# Datenschutzerklärung / Privacy Policy – Wachwerk

**Stand / Last updated:** 9. November 2026 (App 1.2)  
**App:** Wachwerk für iOS und Android  
**Quellcode:** https://github.com/Katschko-IT/Wachbuch-Client

Wachwerk ist ein Open-Source-Client für selbst gehostete Wachwerk-Server. Die App ist weder eine offizielle Behörden-App noch ein Patienten-, Einsatzleit-, Alarmierungs- oder ePCR-System.

## 1. Verantwortungsmodell

Die mobile App stellt **keinen zentralen Wachwerk-Cloud-Dienst** bereit. Nutzer verbinden die App mit einem von ihnen beziehungsweise ihrer Organisation betriebenen Wachwerk-Server. Der Betreiber dieses Servers ist für die dort gespeicherten Organisations- und Benutzerdaten, Aufbewahrungsfristen, Zugriffsrechte sowie Betroffenenrechte verantwortlich.

Der App-Entwickler erhält durch die normale Nutzung der App keinen automatischen Zugriff auf die Inhalte eines fremden selbst gehosteten Servers.

## 2. Welche Daten die App lokal verarbeitet

Die App kann lokal verarbeiten oder speichern:

- die Adresse des ausgewählten Wachwerk-Servers,
- einen vom Server ausgestellten App-Token,
- einen server- und tokengebundenen verschlüsselten Offline-Lesecache (Einzelheiten unten),
- lokal geplante Erinnerungen und die Liste bereits angezeigter Hinweise,
- lokale App-Einstellungen,
- optional einen ungefähren Gerätestandort ausschließlich zur lokalen Berechnung von Sonnenaufgang und Sonnenuntergang für das Tag-/Nacht-Design.

App-Tokens und der Offline-Cache werden über die sicheren Speichermechanismen des Betriebssystems geschützt. Android-Backups und Geräteübertragungen der App-Daten sind im Produktionsmanifest deaktiviert.

**Umfang des Offline-Lesecaches** (nach dem Offline-Vertrag des Servers, `docs/CLIENT-OFFLINE-CONTRACT.md`):

- nur die eigene Mitgliedschaft, Checklisten (Prüfpunkte mit Kennung, Pflicht, Einheit und Grenzwerten; **ohne** den gemeinsamen Zwischenstand der Wache mit Begründungen, Notiz und Namen) und die Übergabeliste ohne Freitext (keine Kaffeekasse, keine Übergabe-Details, keine Mängel, keine Termine, keine Anhänge, keine Dienstanweisungen, keine Hinweise),
- höchstens **24 Stunden** alt; ältere Einträge werden verworfen,
- **kein** Offline-Cache für die Rollen Master-Admin, Kassenwart und Auditor; ein Rollenwechsel löscht den Cache,
- gelesen wird er erst, nachdem die Sitzung online bestätigt wurde; ein Kaltstart ohne Netz zeigt keine Wachendaten.

## 3. Datenübertragung an den selbst gehosteten Server

Für die App-Funktion werden Daten über HTTPS an den vom Nutzer eingerichteten Wachwerk-Server übertragen. Dazu können insbesondere gehören:

- Benutzername und Passwort beim Token-Austausch; das Passwort wird von der App nicht dauerhaft gespeichert,
- App-Token bei authentifizierten API-Anfragen,
- Übergaben, Checklisten, Mängel, Geräte-/Fahrzeugstatus, Inventar-/Poolvorgänge und zugehörige Organisationsdaten,
- neu angelegte Übergaben und Kalendertermine sowie Änderungen an Mängeln,
- die Selbstmeldung „Ich habe bezahlt“ der Kaffeekasse (Betrag, Zahlungsweg, optionale Notiz),
- Ergebnisse von Checklisten-Läufen je Prüfpunkt (Status, Messwerte, Begründungen, Notiz) und der gemeinsame Zwischenstand einer Checkliste (seit 1.2),
- Lesebestätigungen für Dienstanweisungen; der Server speichert dazu Person, Version und Zeitpunkt, keine IP-Adresse und keinen Browser (seit 1.2),
- der Gelesen-Status persönlicher Hinweise, sobald die App einen Hinweis angezeigt hat,
- ausdrücklich vom Nutzer ausgewählte oder aufgenommene Mängelfotos.

Welche Daten der Server anschließend speichert, wie lange sie gespeichert werden und wer darauf zugreifen darf, legt der jeweilige Serverbetreiber fest.

## 4. Kamera und Fotos

Die Kamera wird für drei getrennte Funktionen verwendet:

1. **QR-Servereinrichtung:** Kamerabilder werden zur QR-Erkennung verarbeitet und von der App nicht als Foto gespeichert oder an den Entwickler übertragen.
2. **Mängeldokumentation:** Nur wenn der Nutzer ausdrücklich ein Foto aufnimmt oder aus der Fotomediathek auswählt, wird dieses Bild an den eingerichteten Wachwerk-Server übertragen. „Mangel mit Foto“ öffnet dafür direkt die Kamera; Bilder über 5 MiB verkleinert die App vor dem Versand auf dem Gerät.
3. **QR-Code an Fahrzeug oder Gerät (seit 1.2):** Kamerabilder werden nur zur Erkennung des QR-Codes verarbeitet, um den Bezug eines Mangels vorzuwählen; es wird kein Foto gespeichert oder übertragen.

Die App weist darauf hin, keine Patienten-, Einsatz- oder vergleichbaren sensiblen Fachdaten zu fotografieren.

## 5. Standort

Wenn die Standortberechtigung erteilt wird, verwendet Wachwerk nur einen ungefähren Standort, um Sonnenaufgang und Sonnenuntergang für das lokale Erscheinungsbild zu berechnen. Dieser Standort wird nach aktuellem App-Konzept **nicht an den Wachwerk-Server, den App-Entwickler oder Werbedienste übertragen**. Wird die Berechtigung verweigert, verwendet die App das Systemdesign als Fallback.

### Benachrichtigungen

Mit erteilter Benachrichtigungsberechtigung erinnert die App die Besatzung, wenn ein Fahrzeug nach der Desinfektion freigegeben werden kann. Die Erinnerung wird **lokal auf dem Gerät** geplant; Grundlage sind nur Funkrufname, Sperrzeit und ein kurzer Hinweistext vom eigenen Wachwerk-Server. Seit 1.2 zeigt die App außerdem persönliche Hinweise des Servers zu Fristen (auch die Wochenübersicht), Lesefristen von Dienstanweisungen, fehlenden MPG-Einweisungen und – nur für Master-Admins – technische Hinweise als lokale Benachrichtigung und im Posteingang „Hinweise“. Hinweise, deren Text eine Person nennen kann (fehlende MPG-Einweisung), erscheinen als Benachrichtigung – also womöglich auf dem Sperrbildschirm – nur mit Titel und einem neutralen Text; den vollständigen Text zeigt erst der Posteingang in der App. Es werden keine Daten an den App-Entwickler oder an Werbedienste übertragen. Ohne Berechtigung erscheint der Hinweis nur in der App bzw. im Web.

## 6. Werbung, Tracking und Analyse

Wachwerk enthält nach aktuellem Stand:

- keine Werbung,
- kein Werbe-SDK,
- kein Nutzer-Tracking,
- kein Profiling für Werbung,
- kein externes Analytics-/Crash-Tracking-SDK.

Die App kann technische Fehler des verbundenen Servers anzeigen, sendet aber nicht automatisch Telemetrie an den App-Entwickler.

## 7. Konten und Löschung

Die mobile App erstellt selbst keine zentralen Entwicklerkonten. Benutzerkonten werden auf dem jeweils eingerichteten Wachwerk-Server verwaltet. Anfragen auf Auskunft, Berichtigung oder Löschung serverseitiger Daten sind daher an den Betreiber des betreffenden Servers zu richten.

Beim Abmelden oder Wechsel des Servers entfernt die App das lokale App-Token sowie den zugehörigen Offline-Cache und sperrt die entschlüsselte Schlüsselidentität für Nachrichten. Erkennt der Server die Sitzung nicht mehr an (HTTP 401 oder 403 „Kein aktiver Wachenzugang“), meldet die App ebenso zentral ab. Eine Deinstallation entfernt die App-Daten entsprechend den Mechanismen des Betriebssystems.

## 8. Transport- und Zugriffsschutz

Produktive Serververbindungen müssen HTTPS verwenden. Die App trennt Offline-Caches nach Server und Token und verwendet die sicheren Schlüssel-/Credential-Speicher von iOS und Android. Betreiber eines Wachwerk-Servers sind zusätzlich für TLS, Benutzerverwaltung, Backups, Updates und ihre eigene Datenschutzkonfiguration verantwortlich.

## 9. Drittanbieter-Komponenten

Die App basiert auf Flutter und nutzt Open-Source-Pakete für unter anderem HTTPS-Kommunikation, Secure Storage, QR-Erkennung, Kamera-/Fotoauswahl, Konnektivitätsstatus, lokale Benachrichtigungen und optionalen Standortzugriff. Die App integriert keine Werbe- oder Marketing-SDKs. Änderungen an Abhängigkeiten werden im Repository und in der automatisierten Dependency-Security-Prüfung nachvollzogen.

## 10. Kinder und öffentliche soziale Funktionen

Wachwerk richtet sich an Organisationen und deren autorisierte Nutzer und nicht speziell an Kinder. Es gibt keine öffentliche Social-Networking-, Chat-, Dating- oder frei zugängliche User-Generated-Content-Plattform. Inhalte eines Wachwerk-Servers sind organisationsbezogen und zugriffsgeschützt.

## 11. Änderungen

Wenn sich Datenverarbeitung, Berechtigungen oder integrierte Dienste wesentlich ändern, muss diese Erklärung zusammen mit den App-Store-/Play-Store-Datenschutzangaben aktualisiert werden.

## 12. Kontakt

Fragen zur mobilen Open-Source-App und zu dieser Erklärung können über das öffentliche Repository gestellt werden:

https://github.com/Katschko-IT/Wachbuch-Client/issues

Fragen zu Daten auf einem konkreten Wachwerk-Server sind an den Betreiber dieses Servers zu richten.

---

# English summary

Wachwerk is an open-source client for self-hosted Wachwerk servers. It does not provide a central developer-operated cloud service and is not an official government, patient-record, dispatch, alarm or ePCR application.

The app stores the selected server address locally and protects app tokens and the token/server-scoped offline read cache using operating-system secure storage. The offline read cache holds only the user's own membership, checklists (items with id, required flag, unit and limits, but never the station's shared saved progress) and the handover list without free text, for at most 24 hours; there is no offline cache for the master admin, treasurer and auditor roles, and it is read only after the session has been confirmed online. Signing out or changing servers removes the token and cache and locks the decrypted messaging identity; HTTP 401 or 403 "no active station access" signs the app out centrally.

It sends authentication and operational station data only to the server explicitly configured by the user. Since 1.1 this includes newly created handovers and calendar entries, defect edits, the coffee fund "I have paid" self-report (amount, payment method, optional note) and the read status of personal notices. Since 1.2 it also includes checklist results per item and saved progress (status, measured values, reasons, note) and read confirmations for work instructions (the server stores person, version and time). A password used for token exchange is not persistently stored by the app. Local notifications (for example when a vehicle can be released after disinfection) are scheduled on the device.

Camera frames used for QR setup or for the QR code on a vehicle or device are processed for scanning and are not uploaded as photos. A defect photo is transmitted only when the user explicitly captures or selects one. Approximate location, when permitted, is used locally for sunrise/sunset theme calculation and is not transmitted under the current app design.

The app contains no advertising, advertising SDK, cross-app tracking or external analytics/crash-tracking SDK. Account and server-side data deletion are controlled by the operator of the selected self-hosted server. Signing out or changing servers removes the associated local token and offline cache.

Questions about the mobile app or this policy can be filed at:
https://github.com/Katschko-IT/Wachbuch-Client/issues
