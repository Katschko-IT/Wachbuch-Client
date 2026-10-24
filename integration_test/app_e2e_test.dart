// Ende-zu-Ende-Test der echten App gegen einen laufenden Wachbuch-Server.
//
// Keine Mocks: [WachbuchApp] läuft mit echtem [SessionStore] (Keychain/
// SharedPreferences) und echten HTTP-Aufrufen. Ersetzt wird nur der
// Plattform-Benachrichtigungsplaner, damit kein iOS-Berechtigungsdialog die
// Oberfläche verdeckt.
//
// Aufruf (Server, Konten und Passwort kommen ausschließlich per
// --dart-define, nichts davon steht im Repository):
//
//   flutter test integration_test -d <simulator-id> \
//     --dart-define=E2E_SERVER=http://localhost:18090 \
//     --dart-define=E2E_USER=app.mitglied \
//     --dart-define=E2E_LEAD_USER=app.schicht \
//     --dart-define=E2E_PASSWORD=… \
//     [--dart-define=E2E_HTTPS_SERVER=https://localhost:18443] \
//     [--dart-define=E2E_HTTPS_PIN=<sha256-hex des Leaf-Zertifikats>] \
//     [--dart-define=E2E_SCREENSHOT_DIR=/absoluter/pfad]
//
// Siehe README, Abschnitt „Ende-zu-Ende-Test“.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wachbuch_mobile/api/server_trust.dart';
import 'package:wachbuch_mobile/auth/session_store.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/main.dart';
import 'package:wachbuch_mobile/screens/login_screen.dart';
import 'package:wachbuch_mobile/screens/server_setup_screen.dart';
import 'package:wachbuch_mobile/services/crew_reminder_service.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';

const _server = String.fromEnvironment('E2E_SERVER');
const _user = String.fromEnvironment('E2E_USER', defaultValue: 'app.mitglied');
const _leadUser =
    String.fromEnvironment('E2E_LEAD_USER', defaultValue: 'app.schicht');
const _password = String.fromEnvironment('E2E_PASSWORD');
const _stationName = String.fromEnvironment(
  'E2E_STATION',
  defaultValue: 'Rettungswache Musterstadt',
);
const _defectTitle = String.fromEnvironment(
  'E2E_DEFECT_TITLE',
  defaultValue: 'E2E: Trage klemmt',
);
const _httpsServer = String.fromEnvironment('E2E_HTTPS_SERVER');
const _httpsPin = String.fromEnvironment('E2E_HTTPS_PIN');
const _screenshotDir = String.fromEnvironment('E2E_SCREENSHOT_DIR');

/// Titel der in Schritt b) angelegten Übergabe (für Schritt f).
final _handoverTitle =
    'E2E-App ${DateTime.now().toIso8601String().substring(0, 19)}';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Ohne E2E_SERVER und E2E_PASSWORD (per --dart-define) wird übersprungen.
  const skip = _server == '' || _password == '';

  testWidgets('a–f: Mitglied und Schichtleitung gegen echten Server',
      (tester) async {
    await _startFreshApp(tester);

    // a) Serveradresse, Anmeldung, Übersicht.
    await _enterServer(tester, _server);
    await _shot(tester, '01-login');
    await _login(tester, _user);
    await _pumpUntil(tester, find.text(_stationName));
    expect(find.text(_stationName), findsWidgets);
    expect(find.byType(ErrorBanner), findsNothing);
    await _shot(tester, '02-uebersicht');

    // b) Übergabe anlegen, in der Liste finden, keine Statusaktion.
    final l = _l10n(tester);
    await _openTab(tester, l.navHandovers);
    await tester.tap(find.byKey(const Key('handover-create')));
    await _pumpUntil(tester, find.byKey(const Key('handover-create-title')));
    await _type(
      tester,
      find.byKey(const Key('handover-create-title')),
      _handoverTitle,
    );
    await _type(
      tester,
      find.byKey(const Key('handover-create-details')),
      'Angelegt vom App-Ende-zu-Ende-Test.',
    );
    _hideKeyboard();
    await tester.pump();
    final submit = find.byKey(const Key('handover-create-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await _pumpUntil(tester, find.text(l.handoverCreated));
    await _search(tester, _handoverTitle);
    await _pumpUntil(tester, _handoverCard(_handoverTitle));
    final handoverId = await _serverHandoverId(
      (await SessionStore().readToken())!,
      _handoverTitle,
    );
    debugPrint('E2E: Übergabe angelegt, Server-ID $handoverId');
    expect(handoverId, isNotNull);
    await _shot(tester, '03-uebergaben');
    await _openHandover(tester, _handoverTitle);
    expect(find.byKey(const Key('handover-status-done')), findsNothing);
    expect(find.text(l.defectSetStatus), findsNothing);
    _popTop(tester, find.byKey(const Key('handover-to-defect')));
    await _settle(tester);

    // c) und d) Module aus der Übersicht öffnen.
    await _openTab(tester, l.navOverview);
    final modules = await _visibleModuleTiles(tester);
    debugPrint('E2E: Modul-Kacheln in der Übersicht: $modules');
    expect(modules, contains('module-tile-defects'));

    await _openModule(tester, 'module-tile-defects');
    await _pumpUntil(tester, find.text(_defectTitle));
    expect(find.byType(ErrorBanner), findsNothing);
    await _shot(tester, '04-maengel');
    final showDone = find.byKey(const Key('defects-show-done'));
    expect(tester.widget<SwitchListTile>(showDone).value, isFalse);
    await _tapVisible(tester, showDone);
    await _pumpUntil(
      tester,
      showDone,
      condition: () => tester.widget<SwitchListTile>(showDone).value &&
          tester.widget<SwitchListTile>(showDone).onChanged != null,
    );
    expect(find.byType(ErrorBanner), findsNothing);
    expect(find.text(_defectTitle), findsWidgets);
    await _tapVisible(tester, find.text(_defectTitle).first);
    await _pumpUntil(tester, find.byKey(const Key('defect-status-open')));
    expect(find.byKey(const Key('defect-status-done')), findsNothing,
        reason: 'Mitglied darf Mängel nicht auf „erledigt“ setzen');
    _popTop(tester, find.byKey(const Key('defect-status-open')));
    await _settle(tester);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    for (final tile in const [
      'module-tile-calendar',
      'module-tile-coffee',
      'module-tile-checklists',
    ]) {
      if (!modules.contains(tile)) {
        debugPrint('E2E: $tile nicht in der Navigation (Modul aus) – übersprungen');
        continue;
      }
      await _openModule(tester, tile);
      await _waitForLoad(tester);
      expect(find.byType(ErrorBanner), findsNothing, reason: tile);
      debugPrint('E2E: $tile geöffnet, keine Fehleranzeige');
      await tester.tap(find.byType(BackButton));
      await _settle(tester);
    }

    // e) Abmelden.
    await _logoutViaAccountTab(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await SessionStore().readToken(), isNull);

    // f) Schichtleitung setzt die Übergabe auf „erledigt“.
    await _login(tester, _leadUser);
    await _pumpUntil(tester, find.text(_stationName));
    await _openTab(tester, l.navHandovers);
    await _search(tester, _handoverTitle);
    await _pumpUntil(tester, _handoverCard(_handoverTitle));
    await _openHandover(tester, _handoverTitle);
    final done = find.byKey(const Key('handover-status-done'));
    expect(done, findsOneWidget);
    await _tapVisible(tester, done);
    await _pumpUntil(tester, find.text(l.handoverStatusChanged));
    await _pumpUntil(
      tester,
      done,
      condition: () => tester.widget<ChoiceChip>(done).selected,
    );
    final token = await SessionStore().readToken();
    final serverStatus = await _serverHandoverStatus(token!, handoverId!);
    debugPrint('E2E: Serverstatus der Übergabe: $serverStatus');
    expect(serverStatus, 'done');
    _popTop(tester, done);
    await _settle(tester);
    await _logoutViaAccountTab(tester);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('g: widerrufenes Token führt beim Neuladen zur Anmeldung (C3)',
      (tester) async {
    await _startFreshApp(tester);
    await _enterServer(tester, _server);
    await _login(tester, _user);
    await _pumpUntil(tester, find.text(_stationName));

    final token = await SessionStore().readToken();
    expect(token, isNotNull);
    final status = await _http('DELETE', '/api/v1/token/', token: token);
    expect(status.statusCode, 200, reason: status.body);

    final l = _l10n(tester);
    await tester.tap(find.byTooltip(l.refreshTooltip));
    await _pumpUntil(tester, find.byType(LoginScreen));
    await _pumpUntil(tester, find.text(l.sessionInvalidNotice));
    expect(await SessionStore().readToken(), isNull);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('HTTPS mit Zertifikats-Pin aus dem Verbindungslink',
      (tester) async {
    await _startFreshApp(tester);
    final origin = Uri.parse(_httpsServer);
    String link(String pin) => Uri(
          scheme: 'wachbuch',
          host: 'connect',
          queryParameters: {'url': _httpsServer, 'pin': 'sha256/$pin'},
        ).toString();

    // Falscher Fingerabdruck: Verbindung muss abgelehnt werden.
    await _enterServer(tester, link('0' * 64), expectLogin: false);
    await _pumpUntil(tester, find.byType(ErrorBanner));
    expect(find.byType(ServerSetupScreen), findsOneWidget);
    await ServerTrust.forget('${origin.scheme}://${origin.authority}');

    // Richtiger Fingerabdruck: Anmeldung über HTTPS.
    await _enterServer(tester, link(_httpsPin.toLowerCase()));
    await _login(tester, _user);
    await _pumpUntil(tester, find.text(_stationName));
    expect(find.byType(ErrorBanner), findsNothing);
    await _logoutViaAccountTab(tester);
    await ServerTrust.forget('${origin.scheme}://${origin.authority}');
  },
      skip: skip || _httpsServer == '' || _httpsPin == '',
      timeout: const Timeout(Duration(minutes: 3)));
}

class _NoopScheduler implements ReminderScheduler {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}

Future<void> _startFreshApp(WidgetTester tester) async {
  final store = SessionStore();
  await store.clearAll();
  await tester.pumpWidget(
    WachbuchApp(
      store: store,
      reminderSchedulerFactory: _NoopScheduler.new,
    ),
  );
  await _pumpUntil(tester, find.byType(ServerSetupScreen));
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

Future<void> _enterServer(
  WidgetTester tester,
  String address, {
  bool expectLogin = true,
}) async {
  final field = find.descendant(
    of: find.byType(ServerSetupScreen),
    matching: find.byType(TextFormField),
  );
  await _type(tester, field, address);
  _hideKeyboard();
  await tester.pump();
  await _tapVisible(
    tester,
    find.widgetWithText(FilledButton, _l10n(tester).setupConfirm),
  );
  if (expectLogin) await _pumpUntil(tester, find.byType(LoginScreen));
}

Future<void> _login(WidgetTester tester, String user) async {
  final fields = find.descendant(
    of: find.byType(LoginScreen),
    matching: find.byType(TextFormField),
  );
  await _type(tester, fields.at(0), user);
  await _type(tester, fields.at(1), _password);
  _hideKeyboard();
  await tester.pump();
  await _tapVisible(
    tester,
    find.widgetWithText(FilledButton, _l10n(tester).loginSubmit),
  );
  await _pumpUntil(tester, find.byType(NavigationBar));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await _settle(tester);
}

Future<void> _search(WidgetTester tester, String text) async {
  final field = find.descendant(
    of: find.byKey(const Key('handover-search')),
    matching: find.byType(TextField),
  );
  await _type(tester, field, text);
  _hideKeyboard();
  await _settle(tester);
}

Future<void> _openHandover(WidgetTester tester, String title) async {
  // Nur die Karte, nicht den gleichlautenden Text im Suchfeld.
  await _tapVisible(
    tester,
    find.descendant(of: find.byType(Card), matching: find.text(title)).first,
  );
  await _pumpUntil(tester, find.byKey(const Key('handover-to-defect')));
}

Future<List<String>> _visibleModuleTiles(WidgetTester tester) async {
  // Element einmal festhalten: der Ancestor-Finder verliert beim Scrollen
  // seinen Anker, sobald die Kennzahlen aus dem Bild laufen.
  final scrollableElement = find
      .ancestor(
        of: find.byKey(const Key('overview-stat-open')),
        matching: find.byType(Scrollable),
      )
      .evaluate()
      .first;
  final scrollable =
      find.byElementPredicate((element) => element == scrollableElement);
  await tester.scrollUntilVisible(
    find.text(_l10n(tester).overviewModulesHint),
    300,
    scrollable: scrollable,
  );
  await _settle(tester);
  return [
    for (final key in const [
      'module-tile-calendar',
      'module-tile-coffee',
      'module-tile-checklists',
      'module-tile-defects',
      'module-tile-assets',
      'module-tile-reports',
      'module-tile-chat',
      'module-tile-groups',
      'module-tile-pinboard',
    ])
      if (find.byKey(Key(key)).evaluate().isNotEmpty) key,
  ];
}

Future<void> _openModule(WidgetTester tester, String key) async {
  final tile = find.byKey(Key(key));
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(tile);
  await _settle(tester);
}

Future<void> _logoutViaAccountTab(WidgetTester tester) async {
  final l = _l10n(tester);
  await _openTab(tester, l.navAccount);
  await _tapVisible(tester, find.text(l.accountLogout));
  await _pumpUntil(tester, find.byType(LoginScreen));
}

/// Scrollt [finder] in den sichtbaren Bereich und tippt darauf; ein Tippen
/// außerhalb des Bildschirms würde sonst nur eine Warnung erzeugen.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void _popTop(WidgetTester tester, Finder inside) {
  Navigator.of(tester.element(inside.first)).pop();
}

/// Texteingabe über die Test-Tastatur. Auf dem iOS-Simulator geht ein
/// zweites `enterText` in dasselbe, zwischenzeitlich entfokussierte Feld
/// verloren (Testumgebung, nicht App); dann wird der Wert direkt gesetzt.
Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
  final editable = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  if (editable.controller.text != text) {
    debugPrint('E2E: enterText nicht übernommen – setze Feldinhalt direkt');
    editable.controller.text = text;
    editable.onChanged?.call(text);
    await tester.pump();
  }
}

Finder _handoverCard(String title) =>
    find.descendant(of: find.byType(Card), matching: find.text(title));

void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Pumpt in Echtzeit, bis [finder] etwas findet (und [condition] gilt).
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool Function()? condition,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await tester.pump();
    if (finder.evaluate().isNotEmpty && (condition?.call() ?? true)) return;
  }
  final errors = find.byType(ErrorBanner).evaluate().map(
        (e) => (e.widget as ErrorBanner).message,
      );
  throw TestFailure(
    'Zeitüberschreitung beim Warten auf $finder'
    '${errors.isEmpty ? '' : ' – angezeigte Fehler: ${errors.join(' | ')}'}',
  );
}

/// Wartet kurz, bis Übergangsanimationen durch sind.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

/// Wartet, bis kein Ladeindikator mehr sichtbar ist.
Future<void> _waitForLoad(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  await _settle(tester);
  while (DateTime.now().isBefore(end) &&
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await tester.pump();
  }
  await _settle(tester);
}

/// Bildschirmfoto der gesamten App als PNG nach [_screenshotDir].
Future<void> _shot(WidgetTester tester, String name) async {
  if (_screenshotDir.isEmpty) return;
  await _settle(tester);
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  // Die Wurzelebene skaliert bereits auf physische Pixel.
  final image = await layer.toImage(
    Offset.zero & (view.size * view.flutterView.devicePixelRatio),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final brightness =
      tester.binding.platformDispatcher.platformBrightness == Brightness.dark
          ? 'dunkel'
          : 'hell';
  final file = File('$_screenshotDir/$name-$brightness.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  debugPrint('E2E: Screenshot ${file.path}');
}

class _HttpResult {
  _HttpResult(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

Future<_HttpResult> _http(String method, String path, {String? token}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse('$_server$path'));
    if (token != null) request.headers.set('Authorization', 'Token $token');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return _HttpResult(response.statusCode, body);
  } finally {
    client.close();
  }
}

/// ID der aktiven Übergabe mit [title] laut Server-Liste (nur aktive).
Future<int?> _serverHandoverId(String token, String title) async {
  final result = await _http('GET', '/api/v1/handovers/', token: token);
  final decoded = jsonDecode(result.body);
  final items = decoded is Map ? decoded['results'] : null;
  if (items is! List) return null;
  for (final item in items) {
    if (item is Map && item['title'] == title) return item['id'] as int?;
  }
  return null;
}

/// Status der Übergabe [id] laut Detail-Endpunkt.
Future<String?> _serverHandoverStatus(String token, int id) async {
  final result = await _http('GET', '/api/v1/handovers/$id/', token: token);
  final decoded = jsonDecode(result.body);
  if (decoded is! Map) return null;
  final item = decoded['handover'] is Map ? decoded['handover'] : decoded;
  return (item as Map)['status']?.toString();
}
