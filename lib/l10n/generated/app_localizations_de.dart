// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Wachwerk';

  @override
  String errorSemanticsLabel(String message) {
    return 'Fehler: $message';
  }

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSwitch => 'Wechseln';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get noticeSessionExpired =>
      'Deine Anmeldung ist abgelaufen. Bitte erneut anmelden.';

  @override
  String get noticeSessionEnded => 'Sitzung beendet. Bitte erneut anmelden.';

  @override
  String get serverSwitchTitle => 'Server wechseln?';

  @override
  String serverSwitchMessage(String url) {
    return 'Ein Link möchte die App auf\n$url\numstellen. Die aktuelle Anmeldung wird dabei beendet.';
  }

  @override
  String get navOverview => 'Übersicht';

  @override
  String get navHandovers => 'Übergaben';

  @override
  String get navAccount => 'Konto';

  @override
  String get refreshTooltip => 'Aktualisieren';

  @override
  String get stationFallback => 'Wachwerk';

  @override
  String get sessionExpiredError => 'Anmeldung abgelaufen oder widerrufen.';

  @override
  String get overviewActiveHandovers => 'Aktive Übergaben';

  @override
  String get metricOpen => 'offen';

  @override
  String get metricInProgress => 'in Bearbeitung';

  @override
  String get metricUrgent => 'dringend';

  @override
  String get overviewModulesTitle => 'Module dieser Wache';

  @override
  String get overviewModulesHint =>
      'Deine Wache und die verfügbaren Module werden automatisch aus deinem Benutzerkonto geladen.';

  @override
  String get moduleCalendarTitle => 'Kalender';

  @override
  String get moduleCalendarSubtitle => 'Wachentermine und Dienste';

  @override
  String get moduleCoffeeTitle => 'Kaffeekasse';

  @override
  String get moduleCoffeeSubtitle => 'Kassenstand und Buchungen';

  @override
  String get moduleChecklistsTitle => 'Checklisten';

  @override
  String get moduleChecklistsSubtitle => 'Punkte abhaken und abschließen';

  @override
  String get moduleDefectsTitle => 'Mängel';

  @override
  String get moduleDefectsSubtitle => 'Offene Punkte mit Owner und Frist';

  @override
  String get moduleAssetsTitle => 'Geräte';

  @override
  String get moduleAssetsSubtitle => 'Fahrzeug- und Gerätestatus der Wache';

  @override
  String get moduleReportsTitle => 'Auswertung';

  @override
  String get moduleReportsSubtitle =>
      'Mängel, Fälligkeiten und Einsatzklar-Quote';

  @override
  String get quickAccessTitle => 'Schnellzugriff';

  @override
  String get defectsTitle => 'Mängel';

  @override
  String get defectsHint =>
      'Offene Punkte aus dem Wachalltag — Status und Zuständigkeit nachvollziehbar halten.';

  @override
  String get defectsEmpty => 'Keine Mängel für diesen Filter.';

  @override
  String get defectAdd => 'Mangel anlegen';

  @override
  String get defectCreateTitle => 'Neuen Mangel anlegen';

  @override
  String get defectTitleLabel => 'Titel';

  @override
  String get defectDescriptionLabel => 'Beschreibung';

  @override
  String get defectCategoryLabel => 'Kategorie';

  @override
  String get defectPriorityLabel => 'Priorität';

  @override
  String get defectAssetLabel => 'Bezug';

  @override
  String get defectOwnerLabel => 'Zuständig';

  @override
  String get defectOwnerSelf => 'Mir zuordnen';

  @override
  String get defectDueLabel => 'Frist';

  @override
  String get defectSetStatus => 'Status setzen';

  @override
  String get defectStatusWaiting => 'Wartend';

  @override
  String get defectCreateFailed => 'Mangel konnte nicht angelegt werden.';

  @override
  String get defectPhotosTitle => 'Fotos';

  @override
  String get defectPhotosHint =>
      'Nur Zustandsbilder des Mangels. Keine Patienten- oder Einsatzdaten fotografieren.';

  @override
  String get defectPhotosEmpty => 'Noch keine Fotos.';

  @override
  String get defectAddPhoto => 'Foto hinzufügen';

  @override
  String get defectTakePhoto => 'Kamera';

  @override
  String get defectChoosePhoto => 'Fotomediathek';

  @override
  String get defectPhotoUploadFailed => 'Foto konnte nicht hochgeladen werden.';

  @override
  String get defectPhotoTooLarge => 'Das Bild darf maximal 5 MiB groß sein.';

  @override
  String get defectPhotoUploaded => 'Foto wurde hochgeladen.';

  @override
  String get assetsBoardTitle => 'Fahrzeug- & Gerätestatus';

  @override
  String get assetsScreenTitle => 'Geräte & Status';

  @override
  String get assetsEmpty => 'Keine Geräte oder Pools verfügbar.';

  @override
  String get assetStatusReady => 'Einsatzklar';

  @override
  String get assetStatusLimited => 'Eingeschränkt';

  @override
  String get assetStatusDisinfection => 'Desinfektion';

  @override
  String get assetStatusWorkshop => 'Werkstatt';

  @override
  String get assetStatusOutOfService => 'Außer Dienst';

  @override
  String get assetStatusOob => 'Außer Betrieb';

  @override
  String get assetStatusUnknown => 'Status unbekannt';

  @override
  String get inventoryTitle => 'Schlüssel & Pools';

  @override
  String get inventoryHint =>
      'Checkout / Checkin für Pool-Geräte und Schlüssel.';

  @override
  String get inventoryAvailable => 'Verfügbar';

  @override
  String get inventoryHolderLabel => 'Bei';

  @override
  String get inventoryCheckout => 'Ausgeben';

  @override
  String get inventoryCheckin => 'Zurückgeben';

  @override
  String get checklistIntervalDaily => 'Täglich';

  @override
  String get checklistIntervalWeekly => 'Wöchentlich';

  @override
  String get checklistIntervalMonthly => 'Monatlich';

  @override
  String get checklistDueToday => 'Fällig heute';

  @override
  String get checklistOverdue => 'Überfällig';

  @override
  String get checklistDueSection => 'Fällig heute / überfällig';

  @override
  String get reportsTitle => 'Auswertung';

  @override
  String get reportsHint =>
      'Leichte Stationsübersicht ohne individuelle Leistungsbewertung.';

  @override
  String get reportsOpenDefects => 'Offene Mängel';

  @override
  String get reportsOverdueDefects => 'Mängel überfällig';

  @override
  String get reportsOverdueChecks => 'Checks überfällig';

  @override
  String get reportsAssetReady => 'Assets einsatzklar';

  @override
  String get reportsInventoryOut => 'Pools ausgegeben';

  @override
  String get reportsUnacked => 'Unquittierte Übergaben';

  @override
  String get reportsOldestOpen => 'Ältester offener Mangel';

  @override
  String get reportsDays => 'Tage';

  @override
  String get reportsPrivacyHint =>
      'Diese Auswertung dient der Stationsorganisation, nicht zur Leistungsbewertung einzelner Beschäftigter.';

  @override
  String get handoverAckButton => 'Übernommen';

  @override
  String get handoverAckDone => 'Von dir quittiert';

  @override
  String get handoverAckListTitle => 'Quittierungen';

  @override
  String get handoverAckEmpty => 'Noch nicht quittiert.';

  @override
  String get handoverAckFailed => 'Quittierung fehlgeschlagen.';

  @override
  String get handoverSearchHint => 'Übergaben durchsuchen';

  @override
  String get handoverSearchClear => 'Suche löschen';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterPriority => 'Priorität';

  @override
  String handoversCount(int count, int total) {
    return '$count von $total Übergaben';
  }

  @override
  String filterSectionLabel(String title) {
    return '$title filtern';
  }

  @override
  String get handoversNoneActive => 'Keine aktiven Übergaben.';

  @override
  String get handoversNoneForFilter => 'Keine Übergaben für diese Filter.';

  @override
  String get handoverUntitled => 'ohne Titel';

  @override
  String get handoverFallback => 'Übergabe';

  @override
  String handoverOpenSemantics(String title) {
    return 'Übergabe $title öffnen';
  }

  @override
  String get detailsLoadFailed => 'Details konnten nicht geladen werden.';

  @override
  String get detailsNoFurtherInfo => 'Keine weiteren Angaben.';

  @override
  String detailsUpdatedAt(String timestamp) {
    return 'Aktualisiert $timestamp';
  }

  @override
  String detailsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accountLoggedInAs => 'Angemeldet als';

  @override
  String get accountServer => 'Server';

  @override
  String get accountLicense => 'Lizenz';

  @override
  String get accountLicenseValue => 'AGPL-3.0-or-later · Quellcode offen';

  @override
  String get accountRefreshProfile => 'Profil aktualisieren';

  @override
  String get accountLogout => 'Abmelden';

  @override
  String get accountChangeServer => 'Anderen Server einrichten';

  @override
  String get accountPrivacy => 'Datenschutz';

  @override
  String get offlineCacheTitle => 'Offline-Daten';

  @override
  String get offlineCacheEmpty => 'Keine Offline-Daten gespeichert';

  @override
  String offlineCacheStatus(String age) {
    return 'Zwischengespeicherte Offline-Daten (Stand: $age)';
  }

  @override
  String get offlineCacheClear => 'Offline-Daten löschen';

  @override
  String get offlineCacheCleared => 'Offline-Daten wurden gelöscht.';

  @override
  String get kalenderTitle => 'Kalender';

  @override
  String get kalenderEmpty => 'Keine anstehenden Termine.';

  @override
  String get kalenderEmptyTitle => 'Keine Termine';

  @override
  String get kalenderEntryFallback => 'Termin';

  @override
  String get kalenderTimeTbd => 'Zeit folgt';

  @override
  String get kalenderAllDay => 'Ganztägig';

  @override
  String get kaffeekasseTitle => 'Kaffeekasse';

  @override
  String get kaffeekasseBalanceLabel => 'Aktueller Kassenstand';

  @override
  String get kaffeekasseNegative =>
      'Die Kasse ist im Minus – bitte nachzahlen.';

  @override
  String get kaffeekasseLastTransactions => 'Letzte Buchungen';

  @override
  String get kaffeekasseEmptyLedger => 'Noch keine Buchungen.';

  @override
  String get kaffeekasseEmptyLedgerTitle => 'Keine Buchungen';

  @override
  String get kaffeekasseEntryFallback => 'Buchung';

  @override
  String get checklistenTitle => 'Checklisten';

  @override
  String get checklistenEmpty => 'Keine Checklisten verfügbar.';

  @override
  String get checklistenEmptyTitle => 'Keine Checklisten';

  @override
  String get checklistFallback => 'Checkliste';

  @override
  String get checklistNoItems => 'Keine Punkte.';

  @override
  String get checklistCompleteButton => 'Checkliste abschließen';

  @override
  String get checklistItemFallback => 'Punkt';

  @override
  String checklistCompletedAt(String timestamp) {
    return 'Abgeschlossen $timestamp';
  }

  @override
  String get loginAppBarTitle => 'Anmelden';

  @override
  String get loginChangeServer => 'Server ändern';

  @override
  String get loginHeading => 'Anmeldung';

  @override
  String get loginTokenLabel => 'App-Token (wb_…)';

  @override
  String get loginTokenHelper =>
      'Aus dem Web unter /konto/api/ – nötig bei MFA';

  @override
  String get loginTokenRequired => 'Token erforderlich';

  @override
  String get loginUsername => 'Benutzername';

  @override
  String get loginUsernameRequired => 'Benutzername erforderlich';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginPasswordRequired => 'Passwort erforderlich';

  @override
  String get loginShow => 'Anzeigen';

  @override
  String get loginHide => 'Verbergen';

  @override
  String get loginSubmit => 'Anmelden';

  @override
  String get loginUseCredentials => 'Mit Benutzername und Passwort';

  @override
  String get loginUseToken => 'Stattdessen App-Token nutzen';

  @override
  String get loginTokenPasteHint =>
      'Bitte App-Token einfügen (aus /konto/api/).';

  @override
  String get loginMfaHint =>
      'Bei Zwei-Faktor: App-Token im Web unter Mein Konto → App-Tokens erzeugen.';

  @override
  String get loginInvalidInput => 'Ungültige Eingabe.';

  @override
  String get setupServerAddressTitle => 'Server-Adresse deiner Wache';

  @override
  String get setupHint =>
      'Gib die Adresse ein oder scanne den QR-Code aus dem Web.';

  @override
  String get setupAddressLabel => 'Adresse';

  @override
  String get setupAddressHint => 'https://wache.example.org';

  @override
  String get setupScanQr => 'QR-Code scannen';

  @override
  String get setupAddressRequired => 'Adresse eingeben';

  @override
  String get setupAddressInvalid => 'Ungültige Adresse';

  @override
  String get setupConfirm => 'Bestätigen';

  @override
  String get setupFooter =>
      'Play-Store-Client: Verbindung nur zu deinem selbst gehosteten Server. Produktion: HTTPS erforderlich.';

  @override
  String get setupDemoButton => 'Demo-Modus ausprobieren';

  @override
  String get setupDemoTitle => 'Demo-Modus wählen';

  @override
  String get setupDemoSubtitle =>
      'Lokale Musterdaten ohne Server — für Rettungsdienst, Feuerwehr, FFW oder Polizei.';

  @override
  String get setupDemoRettungsdienst => 'Rettungsdienst';

  @override
  String get setupDemoRettungsdienstHint =>
      'Schichtübergabe & Material auf der Rettungswache';

  @override
  String get setupDemoFeuerwehr => 'Feuerwehr';

  @override
  String get setupDemoFeuerwehrHint =>
      'Gerätehaus, Fahrzeuge und Dienstübergabe';

  @override
  String get setupDemoFfw => 'Freiwillige Feuerwehr';

  @override
  String get setupDemoFfwHint =>
      'Gerätehaus, Fahrzeuge und ehrenamtlicher Wachalltag';

  @override
  String get setupDemoPolizei => 'Polizei';

  @override
  String get setupDemoPolizeiHint => 'Wachalltag, Material und Dienstgruppe';

  @override
  String get demoBannerLabel => 'Demo-Modus';

  @override
  String get demoBannerRettungsdienst => 'Rettungsdienst';

  @override
  String get demoBannerFeuerwehr => 'Feuerwehr';

  @override
  String get demoBannerFfw => 'Freiwillige Feuerwehr';

  @override
  String get demoBannerPolizei => 'Polizei';

  @override
  String get qrScanTitle => 'Server-QR scannen';

  @override
  String get qrScanCameraHint =>
      'Die Kamera wird hier nur zum Lesen der Server-Adresse genutzt. Es werden dabei keine Fotos gespeichert oder hochgeladen.';

  @override
  String get qrScanInvalid => 'Kein gültiger Wachwerk-Server-QR.';

  @override
  String get qrScanWebHint =>
      'QR aus dem Wachwerk-Web unter Mein Konto → App-Tokens';

  @override
  String get qrCameraDialogTitle => 'Kamera für QR-Code';

  @override
  String get qrCameraDialogMessage =>
      'Wachwerk benötigt die Kamera hier ausschließlich, um den QR-Code mit der Server-Adresse deiner Wache zu scannen. Ohne Kamera kannst du die Adresse auch manuell eingeben.';

  @override
  String get qrCameraContinue => 'Weiter';

  @override
  String get qrCameraDeniedTitle => 'Kamera nicht freigegeben';

  @override
  String get qrCameraDeniedMessage =>
      'Ohne Kamerazugriff kannst du den QR nicht scannen. Gib die Server-Adresse manuell ein oder aktiviere die Kamera in den Systemeinstellungen.';

  @override
  String get qrCameraOk => 'OK';

  @override
  String get qrCameraSettings => 'Einstellungen';

  @override
  String get handoverStatusOpen => 'Offen';

  @override
  String get handoverStatusInProgress => 'In Bearbeitung';

  @override
  String get handoverStatusDone => 'Erledigt';

  @override
  String get handoverPriorityNormal => 'Normal';

  @override
  String get handoverPriorityImportant => 'Wichtig';

  @override
  String get handoverPriorityUrgent => 'Dringend';

  @override
  String get handoverCategoryStation => 'Wache';

  @override
  String get handoverCategoryVehicle => 'Fahrzeugstatus';

  @override
  String get handoverCategoryMaterial => 'Material';

  @override
  String get handoverCategoryTask => 'Offene Aufgabe';

  @override
  String get handoverCategorySafety => 'Sicherheit/Mangel';

  @override
  String get handoverEnumUnknown => 'Nicht angegeben';

  @override
  String get chatTitle => 'Wachenchat';

  @override
  String get chatSubtitle => 'Ende-zu-Ende verschlüsselt';

  @override
  String get chatSetupTitle => 'Chat-Schlüssel einrichten';

  @override
  String get chatSetupHint =>
      'Lege eine Passphrase fest. Sie schützt deinen privaten Schlüssel und wird nie an den Server übertragen.';

  @override
  String get chatSetupAction => 'Schlüssel erstellen';

  @override
  String get chatUnlockTitle => 'Chat entsperren';

  @override
  String get chatUnlockHint =>
      'Gib deine Passphrase ein, um verschlüsselte Nachrichten zu lesen und zu schreiben.';

  @override
  String get chatUnlockAction => 'Entsperren';

  @override
  String get chatPassphrase => 'Passphrase';

  @override
  String get chatWrongPassphrase =>
      'Falsche Passphrase oder beschädigter Schlüssel.';

  @override
  String get chatComposeHint => 'Kurze Nachricht an die Wache …';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatEmpty => 'Noch keine Nachrichten.';

  @override
  String get chatUnreadable =>
      'Nachricht nicht lesbar (kein Schlüssel für dich).';

  @override
  String get chatLoadError => 'Chat konnte nicht geladen werden.';

  @override
  String get chatMe => 'Ich';

  @override
  String get groupsTitle => 'Gruppen';

  @override
  String get groupsSubtitle => 'Gruppen-Chats (Ende-zu-Ende)';

  @override
  String get groupsEmpty => 'Noch keine Gruppen.';

  @override
  String get groupsCreate => 'Gruppe erstellen';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get groupMembers => 'Mitglieder';

  @override
  String get groupCreateAction => 'Erstellen';

  @override
  String get groupSelectMembers => 'Mitglieder auswählen';

  @override
  String get groupNoColleagues =>
      'Keine Kolleginnen und Kollegen mit Schlüsseln verfügbar.';

  @override
  String get pinboardTitle => 'Pinnwand';

  @override
  String get pinboardSubtitle => 'Aushänge und Hinweise für die Wache';

  @override
  String get pinboardEmpty => 'Noch keine Aushänge an der Pinnwand.';

  @override
  String get pinboardCreate => 'Aushang anlegen';

  @override
  String get pinboardFieldTitle => 'Titel';

  @override
  String get pinboardFieldBody => 'Text';

  @override
  String get pinboardCategory => 'Art';

  @override
  String get pinboardPinned => 'Angepinnt';

  @override
  String get pinboardSave => 'Speichern';

  @override
  String get pinboardCancel => 'Abbrechen';

  @override
  String get pinboardCategoryInfo => 'Info';

  @override
  String get pinboardCategoryImportant => 'Wichtig';

  @override
  String get pinboardCategoryEvent => 'Termin/Hinweis';

  @override
  String get pinboardLoadError => 'Pinnwand konnte nicht geladen werden.';

  @override
  String get pinboardCreated => 'Aushang wurde angelegt.';

  @override
  String get updateTitleAvailable => 'Neue Version verfügbar';

  @override
  String get updateTitleRequired => 'Wichtiges Update erforderlich';

  @override
  String updateCurrentVersion(Object version) {
    return 'Aktuelle Version: $version';
  }

  @override
  String updateNewVersion(Object version) {
    return 'Neue Version: $version';
  }

  @override
  String updateReleasedAt(Object date) {
    return 'Veröffentlicht am: $date';
  }

  @override
  String get updateWhatsNew => 'Was gibt es Neues?';

  @override
  String get updateRequiredNotice =>
      'Dieses Update ist erforderlich, um die App weiter nutzen zu können.';

  @override
  String get updateForceExplanation =>
      'Um die App weiter nutzen zu können, musst du auf die neueste Version updaten.';

  @override
  String updateRequiredVersion(Object version) {
    return 'Erforderliche Version: $version';
  }

  @override
  String get updateLater => 'Später erinnern';

  @override
  String get updateClose => 'Schließen';

  @override
  String get updateDownload => 'Update herunterladen';

  @override
  String get updateNow => 'Jetzt updaten';

  @override
  String updateVersionEntry(Object version) {
    return 'Version $version';
  }

  @override
  String get keyVerifyTitle => 'Schlüssel verifizieren';

  @override
  String get keyVerifyExplanation =>
      'Vergleiche den Fingerprint deines Schlüssels mit dem deiner Kolleginnen und Kollegen – persönlich oder per QR-Scan. Stimmen sie überein, ist der Schlüssel echt.';

  @override
  String get keyVerifyOwnKey => 'Dein Schlüssel';

  @override
  String get keyVerifyOwnTag => '(du)';

  @override
  String get keyVerifyVerifiedTag => 'verifiziert';

  @override
  String get keyVerifyScanAction => 'Per Scan verifizieren';

  @override
  String get keyVerifyScanTitle => 'Fingerprint scannen';

  @override
  String keyVerifyMatch(Object name) {
    return 'Fingerprint stimmt mit $name überein.';
  }

  @override
  String get keyVerifyNoMatch =>
      'Kein Mitglied mit diesem Fingerprint gefunden.';

  @override
  String get keyVerifyCopied => 'Fingerprint kopiert.';

  @override
  String get keyVerifyShowQr => 'QR-Code anzeigen';

  @override
  String get keyVerifyConfirmAction => 'Als verifiziert markieren';

  @override
  String get keyVerifyRevoke => 'Verifizierung zurückziehen';

  @override
  String keyVerifyReverified(Object name) {
    return 'Geänderter Schlüssel von $name erneut verifiziert.';
  }

  @override
  String get keyVerifyChangedTag => 'Schlüssel geändert!';

  @override
  String keyVerifyChangedWarning(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verifizierte Schlüssel haben sich geändert',
      one: '$count verifizierter Schlüssel hat sich geändert',
    );
    return '$_temp0. Bitte persönlich erneut prüfen.';
  }

  @override
  String keyVerifyServerMismatch(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vom Server gemeldete Fingerprints weichen vom Schlüssel ab',
      one: '$count vom Server gemeldeter Fingerprint weicht vom Schlüssel ab',
    );
    return '$_temp0. Mögliche Server-Manipulation – nicht verifizieren.';
  }

  @override
  String get handoverCreate => 'Neue Übergabe';

  @override
  String get handoverCreateHeading => 'Übergabe anlegen';

  @override
  String get handoverFieldTitle => 'Titel';

  @override
  String get handoverFieldDetails => 'Was ist zu übergeben?';

  @override
  String get handoverFieldCategory => 'Bereich';

  @override
  String get handoverFieldPriority => 'Dringlichkeit';

  @override
  String get handoverTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get handoverDetailsRequired =>
      'Bitte kurz beschreiben, worum es geht.';

  @override
  String get handoverSave => 'Übergabe speichern';

  @override
  String get handoverCreated => 'Übergabe gespeichert.';

  @override
  String get handoverCreateFailed =>
      'Übergabe konnte nicht gespeichert werden.';

  @override
  String get handoverStatusTitle => 'Status';

  @override
  String handoverStatusChanged(String status) {
    return 'Status: $status';
  }

  @override
  String get handoverStatusFailed => 'Status konnte nicht geändert werden.';

  @override
  String get kaffeekasseMyStatus => 'Mein Stand';

  @override
  String get kaffeekasseOpen => 'Offen';

  @override
  String get kaffeekasseCredit => 'Guthaben';

  @override
  String get kaffeekasseAllPaid => 'Alles bezahlt';

  @override
  String get kaffeekasseNotParticipant =>
      'Du bist (noch) nicht für den Monatsbeitrag eingetragen. Sprich bitte den Kassenwart an.';

  @override
  String get kaffeekasseMonthsTitle => 'Meine Monate';

  @override
  String get kaffeekasseMonthPaid => 'bezahlt';

  @override
  String kaffeekasseMonthOpen(String amount) {
    return 'offen $amount';
  }

  @override
  String get kaffeekasseMonthWaived => 'befreit';

  @override
  String get kaffeekasseIPaid => 'Ich habe bezahlt';

  @override
  String get kaffeekassePayHint =>
      'Wie das Kreuz in der Mappe: Trag ein, was du in die Kasse gelegt oder überwiesen hast.';

  @override
  String get kaffeekassePayMethod => 'Wie hast du bezahlt?';

  @override
  String get kaffeekasseMethodCash => 'Bar in die Kasse';

  @override
  String get kaffeekasseMethodTransfer => 'Überweisung';

  @override
  String get kaffeekasseAmount => 'Betrag';

  @override
  String get kaffeekasseAmountInvalid =>
      'Bitte einen Betrag zwischen 0,01 und 500 € eingeben.';

  @override
  String get kaffeekasseNote => 'Notiz (optional)';

  @override
  String get kaffeekassePaySubmit => 'Zahlung eintragen';

  @override
  String get kaffeekassePaid => 'Danke! Deine Zahlung ist eingetragen.';

  @override
  String get kaffeekassePayFailed => 'Zahlung konnte nicht eingetragen werden.';

  @override
  String get kaffeekasseTransferTitle => 'Überweisen';

  @override
  String get kaffeekasseRecipient => 'Empfänger';

  @override
  String get kaffeekasseIban => 'IBAN';

  @override
  String get kaffeekasseSuggested => 'Betrag';

  @override
  String get kaffeekasseReference => 'Verwendungszweck';

  @override
  String get kaffeekasseOpenPaypal => 'PayPal öffnen';

  @override
  String get kaffeekasseOpenWero => 'Wero öffnen';

  @override
  String get kalenderCreate => 'Termin anlegen';

  @override
  String get kalenderFieldTitle => 'Titel';

  @override
  String get kalenderFieldDescription => 'Beschreibung (optional)';

  @override
  String get kalenderFieldStart => 'Beginn';

  @override
  String get kalenderFieldEnd => 'Ende';

  @override
  String get kalenderTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get kalenderEndBeforeStart =>
      'Das Ende darf nicht vor dem Beginn liegen.';

  @override
  String get kalenderSave => 'Termin speichern';

  @override
  String get kalenderCreated => 'Termin gespeichert.';

  @override
  String get kalenderCreateFailed => 'Termin konnte nicht gespeichert werden.';

  @override
  String get defectEdit => 'Bearbeiten';

  @override
  String get defectUpdated => 'Mangel aktualisiert.';

  @override
  String get defectUpdateFailed => 'Mangel konnte nicht aktualisiert werden.';

  @override
  String get defectDueClear => 'Frist entfernen';

  @override
  String get attachmentPreviewUnavailable => 'Vorschau nicht verfügbar';

  @override
  String attachmentFileInfo(String filename, String contentType) {
    return '$filename ($contentType)';
  }

  @override
  String get sessionInvalidNotice =>
      'Anmeldung abgelaufen oder widerrufen. Bitte erneut anmelden.';

  @override
  String get sessionNoMembershipNotice =>
      'Für dieses Konto gibt es keinen aktiven Wachenzugang. Bitte an die Wachenleitung wenden.';

  @override
  String get freeTextBoundaryHint =>
      'Keine Patienten- oder Einsatzdaten eintragen.';

  @override
  String get handoverNoAutoRetryHint =>
      'Wird einmal gesendet. Bei einem Fehler bitte die Liste prüfen, bevor du erneut sendest.';

  @override
  String get defectsShowDone => 'Erledigte anzeigen';

  @override
  String get defectsLoadMore => 'Mehr laden';

  @override
  String defectsShownOfTotal(int shown, int total) {
    return '$shown von $total Mängeln';
  }

  @override
  String get kaffeekasseBalanceStation => 'Kassenstand der Wache';

  @override
  String get kaffeekasseBalanceOwn => 'Mein Saldo';

  @override
  String get checklistRunStart => 'Prüfung starten';

  @override
  String get checklistRunResume => 'Zwischenstand fortsetzen';

  @override
  String get checklistRunAgain => 'Erneut prüfen';

  @override
  String checklistItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Prüfpunkte',
      one: '$count Prüfpunkt',
    );
    return '$_temp0';
  }

  @override
  String get checklistRequiredBadge => 'Pflicht';

  @override
  String checklistRequiredSemantics(String item) {
    return 'Pflichtpunkt: $item';
  }

  @override
  String checklistLimitsRange(String min, String max) {
    return 'Grenzwerte $min bis $max';
  }

  @override
  String checklistLimitsMin(String min) {
    return 'mindestens $min';
  }

  @override
  String checklistLimitsMax(String max) {
    return 'höchstens $max';
  }

  @override
  String get checklistValueLabel => 'Messwert';

  @override
  String get checklistValueOutOfLimits =>
      'Außerhalb der Grenzwerte: Beim Abschluss wird der Punkt „nicht in Ordnung“.';

  @override
  String get checklistStatusOk => 'In Ordnung';

  @override
  String get checklistStatusNotOk => 'Nicht in Ordnung';

  @override
  String get checklistStatusNa => 'Entfällt';

  @override
  String get checklistStatusOpen => 'nicht bewertet';

  @override
  String get checklistReasonRequiredLabel => 'Begründung (Pflicht)';

  @override
  String get checklistFindingLabel => 'Feststellung (optional)';

  @override
  String get checklistNoteLabel => 'Notiz zum Lauf (optional)';

  @override
  String get checklistSaveDraft => 'Zwischenstand speichern';

  @override
  String get checklistDraftSaved =>
      'Zwischenstand gespeichert. Die nächste Person kann fortsetzen.';

  @override
  String get checklistFinish => 'Abschließen';

  @override
  String checklistDraftInfo(String time, String name) {
    return 'Zwischenstand vom $time · $name';
  }

  @override
  String checklistDraftLoaded(String time, String name) {
    return 'Zwischenstand vom $time · $name geladen.';
  }

  @override
  String checklistDraftLoadFailed(String message) {
    return 'Zwischenstand konnte nicht geladen werden: $message';
  }

  @override
  String get checklistDraftShared =>
      'Der Zwischenstand gehört der Wache: Speichern ersetzt ihn für alle.';

  @override
  String get checklistValidationFailed =>
      'Der Server hat den Lauf nicht angenommen. Deine Eingaben sind erhalten.';

  @override
  String get checklistRunDoneTitle => 'Checkliste abgeschlossen';

  @override
  String get checklistRunResultsTitle => 'Ergebnis wie gespeichert';

  @override
  String checklistRunDefectCreated(int id) {
    return 'Mangel #$id angelegt';
  }

  @override
  String checklistRunDefectLinked(int id) {
    return 'Mit offenem Mangel #$id verknüpft';
  }

  @override
  String get checklistRunOpenDefects => 'Mängel öffnen';

  @override
  String get checklistRunDone => 'Fertig';

  @override
  String get checklistDiscardTitle => 'Eingaben verwerfen?';

  @override
  String get checklistDiscardMessage =>
      'Nicht gespeicherte Eingaben gehen verloren. Mit „Zwischenstand speichern“ kann die nächste Person weitermachen.';

  @override
  String get checklistDiscardConfirm => 'Verwerfen';

  @override
  String get checklistContinueEditing => 'Weiter bearbeiten';

  @override
  String get checklistPaperBackfillMarker => 'Nachtrag vom Papierbogen';

  @override
  String get defectQuickTitle => 'Mangel melden';

  @override
  String get defectQuickWithPhoto => 'Mangel mit Foto';

  @override
  String get defectQuickPhotoCamera => 'Foto aufnehmen';

  @override
  String get defectQuickPhotoGallery => 'Aus Mediathek';

  @override
  String get defectQuickPhotoRemove => 'Foto entfernen';

  @override
  String defectQuickPhotoReady(String size) {
    return 'Foto bereit ($size)';
  }

  @override
  String get defectQuickPhotoDownscaled =>
      'Das Foto wurde für den Versand verkleinert.';

  @override
  String get defectQuickPhotoUnsupported =>
      'Dieses Bildformat wird nicht unterstützt (JPEG, PNG oder WebP).';

  @override
  String get defectQuickPhotoUnavailable =>
      'Kamera oder Mediathek ist nicht verfügbar.';

  @override
  String get defectReferenceNone => 'Ohne Bezug';

  @override
  String get defectReferenceOther => 'Anderer Bezug (Freitext)';

  @override
  String get defectReferenceText => 'Bezug als Text';

  @override
  String get defectReferenceGroupVehicles => 'Fahrzeuge';

  @override
  String get defectReferenceGroupDevices => 'Geräte';

  @override
  String get defectReferenceGroupKeys => 'Schlüssel';

  @override
  String get defectReferenceScanQr => 'QR-Code am Fahrzeug oder Gerät scannen';

  @override
  String get defectReferenceQrNoMatch =>
      'Zu diesem QR-Code gibt es keinen Eintrag in „Geräte & Fahrzeuge“ dieser Wache.';

  @override
  String get defectTitleOptionalLabel => 'Titel (optional)';

  @override
  String defectTitleAutoHint(String title) {
    return 'Leer lassen ergibt: $title';
  }

  @override
  String defectAutoTitle(String category, String reference) {
    return '$category: $reference';
  }

  @override
  String defectAutoTitleNoReference(String category) {
    return '$category: ohne Bezug';
  }

  @override
  String get defectNeedsContent =>
      'Bitte ein Foto, einen Bezug, einen Titel oder eine Beschreibung angeben.';

  @override
  String get defectDuplicateTitle => 'Bereits gemeldet';

  @override
  String defectDuplicateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count offene Mängel zu diesem Bezug. Bitte prüfen, ob es derselbe ist.',
      one:
          '$count offener Mangel zu diesem Bezug. Bitte prüfen, ob es derselbe ist.',
    );
    return '$_temp0';
  }

  @override
  String get defectCreated => 'Mangel angelegt.';

  @override
  String get defectCreatedWithPhoto => 'Mangel mit Foto angelegt.';

  @override
  String defectCreatedPhotoFailed(String message) {
    return 'Mangel angelegt, Foto nicht hochgeladen: $message Das Foto kann im Mangel erneut hinzugefügt werden.';
  }

  @override
  String get defectCategoryVehicle => 'Fahrzeug';

  @override
  String get defectCategoryMaterial => 'Material';

  @override
  String get defectCategorySafety => 'Sicherheit';

  @override
  String get defectCategoryFacility => 'Gebäude';

  @override
  String get defectCategoryKey => 'Schlüssel';

  @override
  String get defectCategoryDevice => 'Gerät';

  @override
  String get defectCategoryTask => 'Aufgabe';

  @override
  String get defectQrCameraMessage =>
      'Wachwerk nutzt die Kamera hier nur, um den QR-Code am Fahrzeug oder Gerät zu lesen. Es wird dabei kein Foto gespeichert.';

  @override
  String get defectQrScanTitle => 'QR-Code am Fahrzeug oder Gerät';

  @override
  String get defectQrScanInvalid =>
      'Kein QR-Code eines Fahrzeugs oder Geräts dieses Servers.';

  @override
  String get defectQrCameraDenied =>
      'Ohne Kamerazugriff kannst du den QR-Code nicht scannen. Wähle den Bezug aus der Liste oder aktiviere die Kamera in den Systemeinstellungen.';

  @override
  String get sopScreenTitle => 'Dienstanweisungen lesen';

  @override
  String get sopStartCardTitle => 'Dienstanweisungen lesen';

  @override
  String sopOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offen',
      one: '$count offen',
    );
    return '$_temp0';
  }

  @override
  String sopOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count überfällig',
      one: '$count überfällig',
    );
    return '$_temp0';
  }

  @override
  String sopRevision(String version) {
    return 'Version $version';
  }

  @override
  String sopDue(String date) {
    return 'Lesen bis $date';
  }

  @override
  String sopOverdue(String date) {
    return 'Überfällig seit $date';
  }

  @override
  String sopAcknowledgedAt(String date) {
    return 'Bestätigt am $date';
  }

  @override
  String get sopOpenText => 'Text öffnen';

  @override
  String get sopAcknowledge => 'Gelesen und verstanden';

  @override
  String get sopAckConfirmTitle => 'Lesen bestätigen?';

  @override
  String get sopAckConfirmMessage =>
      'Bestätige nur, was du gelesen und verstanden hast. Gespeichert werden Person, Version und Zeitpunkt.';

  @override
  String get sopAckConfirm => 'Bestätigen';

  @override
  String get sopAckDone => 'Lesebestätigung gespeichert.';

  @override
  String get sopAckNewerVersion =>
      'Es gibt eine neuere Version. Bitte zuerst die aktuelle Fassung lesen.';

  @override
  String get sopEmptyTitle => 'Alles gelesen';

  @override
  String get sopEmpty => 'Keine offenen Dienstanweisungen.';

  @override
  String get sopUnavailable =>
      'Dieser Server bietet Lesebestätigungen in der App erst ab Wachwerk 0.28.';

  @override
  String get sopShowAcknowledged => 'Auch bestätigte anzeigen';

  @override
  String get sopOpenFailed => 'Die Seite konnte nicht geöffnet werden.';

  @override
  String get noticesTitle => 'Hinweise';

  @override
  String get noticesEmpty => 'Keine Hinweise.';

  @override
  String get noticesHint =>
      'Hinweise erscheinen auch als Benachrichtigung auf dem Gerät und gelten danach als gelesen.';

  @override
  String get noticeKindVehicleReady => 'Fahrzeugfreigabe';

  @override
  String get noticeKindCoffeeDue => 'Kaffeekasse';

  @override
  String get noticeKindDeadline => 'Frist';

  @override
  String get noticeKindDigest => 'Wochenübersicht';

  @override
  String get noticeKindSop => 'Lesefrist';

  @override
  String get noticeKindMpgTraining => 'MPG-Einweisung';

  @override
  String get noticeKindSystemHealth => 'Technik';

  @override
  String get noticeUnread => 'neu';

  @override
  String get noticeOpenInBrowser => 'Im Browser öffnen';

  @override
  String get handoverPaperBackfill => 'Nachtrag vom Papierbogen';

  @override
  String handoverPaperBackfillEvent(String occurred) {
    return 'Nachtrag vom Papierbogen · Ereignis $occurred';
  }

  @override
  String handoverPaperBackfillFull(String occurred, String recorded) {
    return 'Nachtrag vom Papierbogen · Ereignis $occurred · erfasst $recorded';
  }
}
