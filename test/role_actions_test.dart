import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/assets_screen.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';
import 'package:wachbuch_mobile/state/station_roles.dart';

import 'test_localization.dart';

/// Rollen wie core/api/wachalltag.py: Asset-Status, Mangel erledigt und
/// fremde Rückgabe nur für WRITE_ROLES (shift_lead, admin).
class _RoleApi extends WachbuchApi {
  _RoleApi({this.role = 'member'})
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final String role;

  @override
  Future<Map<String, dynamic>> me() async => {
        'user': {'id': 7, 'username': 'michael'},
        'membership': {'role': role, 'station': {'name': 'Wache'}},
      };

  @override
  Future<List<StationAsset>> assets() async => const [
        StationAsset(id: 'rtw1', label: 'RTW 1', kind: 'vehicle'),
      ];

  @override
  Future<List<InventoryItem>> inventory() async => const [
        InventoryItem(id: 'k1', label: 'Schlüssel Halle', holder: 'anna'),
        InventoryItem(id: 'k2', label: 'Funkgerät 2', holder: 'michael'),
      ];

  @override
  Future<DefectPage> defectsPage({bool includeDone = false, int limit = 100}) async =>
      const DefectPage(items: [Defect(id: 1, title: 'Trage quietscht')], count: 1);

  @override
  Future<List<DefectAttachment>> defectAttachments(int defectId) async => const [];
}

/// Startseite mit Kalender-Modul; Rolle kommt wie in der App aus `/me/`.
class _ShellApi extends WachbuchApi {
  _ShellApi(this.role)
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final String role;

  @override
  Future<Map<String, dynamic>> me() async => {
        'user': {'id': 7, 'username': 'michael'},
        'membership': {
          'role': role,
          'role_label': role,
          'station': {
            'name': 'Wache',
            'modules': {'calendar': true},
          },
        },
      };

  @override
  Future<List<Map<String, dynamic>>> handovers() async => const [];

  @override
  Future<List<KalenderEntry>> kalender() async => const [];
}

Future<void> _openCalendarFromShell(WidgetTester tester, String role) async {
  _usePhone(tester);
  await tester.pumpWidget(
    localizedApp(
      home: HomeShell(
        api: _ShellApi(role),
        onLogout: () async {},
        onChangeServer: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  final tile = find.byKey(const Key('module-tile-calendar'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _inventoryButton(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Card)),
      matching: find.byType(FilledButton),
    );

void main() {
  test('StationRoles spiegelt den Server', () {
    // core/api/views.py calendar_api: WRITE_ROLES.
    for (final role in ['shift_lead', 'admin']) {
      expect(StationRoles.canCreateCalendarEntry(role), isTrue, reason: role);
    }
    for (final role in ['member', 'cashier', 'auditor', null]) {
      expect(StationRoles.canCreateCalendarEntry(role), isFalse, reason: '$role');
    }
    // core/api/wachalltag.py defect_detail PATCH: CONTENT_ROLES.
    for (final role in ['member', 'shift_lead', 'cashier', 'admin']) {
      expect(StationRoles.canEditDefect(role), isTrue, reason: role);
    }
    for (final role in ['auditor', null]) {
      expect(StationRoles.canEditDefect(role), isFalse, reason: '$role');
    }
    // POST /api/v1/handovers/: CONTENT_ROLES, also kein Prüfer.
    expect(StationRoles.canCreateHandover('auditor'), isFalse);
    expect(StationRoles.canCreateHandover('member'), isTrue);
  });

  test('Rollen entsprechen WRITE_ROLES des Servers', () {
    expect(StationRoles.writeRoles, {'shift_lead', 'admin'});
    expect(StationRoles.canChangeAssetStatus('cashier'), isFalse);
    expect(StationRoles.canCloseDefect('admin'), isTrue);
    expect(
      StationRoles.canCheckin(role: 'member', holder: 'anna', username: 'michael'),
      isFalse,
    );
  });

  group('Geräte', () {
    testWidgets('Mitglied kann den Asset-Status nicht ändern', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(localizedApp(home: AssetsScreen(api: _RoleApi())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RTW 1'));
      await tester.pumpAndSettle();
      expect(find.text('Speichern'), findsNothing);
    });

    testWidgets('Schichtleitung kann den Asset-Status ändern', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(home: AssetsScreen(api: _RoleApi(role: 'shift_lead'))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('RTW 1'));
      await tester.pumpAndSettle();
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('fremde Ausleihe: Rückgabe nur mit Schreibrolle', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(localizedApp(home: AssetsScreen(api: _RoleApi())));
      await tester.pumpAndSettle();

      expect(_inventoryButton('Schlüssel Halle'), findsNothing);
      expect(_inventoryButton('Funkgerät 2'), findsOneWidget);
    });

    testWidgets('Schichtleitung darf fremde Ausleihe zurückgeben', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(home: AssetsScreen(api: _RoleApi(role: 'admin'))),
      );
      await tester.pumpAndSettle();

      expect(_inventoryButton('Schlüssel Halle'), findsOneWidget);
    });

    testWidgets('übergebene Rolle hat Vorrang vor /me/', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(
          home: AssetsScreen(
            api: _RoleApi(role: 'shift_lead'),
            role: 'member',
            username: 'michael',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('RTW 1'));
      await tester.pumpAndSettle();
      expect(find.text('Speichern'), findsNothing);
    });
  });

  group('Mängel', () {
    Future<void> openDetail(WidgetTester tester, String role) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(home: DefectsScreen(api: _RoleApi(role: role))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trage quietscht'));
      await tester.pumpAndSettle();
    }

    testWidgets('Mitglied kann einen Mangel nicht auf erledigt setzen', (tester) async {
      await openDetail(tester, 'member');

      expect(find.byKey(const Key('defect-status-in_progress')), findsOneWidget);
      expect(find.byKey(const Key('defect-status-done')), findsNothing);
    });

    testWidgets('Schichtleitung kann einen Mangel abschließen', (tester) async {
      await openDetail(tester, 'shift_lead');

      expect(find.byKey(const Key('defect-status-done')), findsOneWidget);
    });

    testWidgets('Auditor sieht im Mangel kein „Bearbeiten“', (tester) async {
      await openDetail(tester, 'auditor');

      expect(find.byKey(const Key('defect-edit')), findsNothing);
    });

    testWidgets('Mitglied kann einen Mangel bearbeiten', (tester) async {
      await openDetail(tester, 'member');

      expect(find.byKey(const Key('defect-edit')), findsOneWidget);
    });

    testWidgets('übergebene Rolle Auditor blendet „Bearbeiten“ aus', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(
          home: DefectsScreen(api: _RoleApi(role: 'shift_lead'), role: 'auditor'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trage quietscht'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('defect-edit')), findsNothing);
    });
  });

  group('Kalender', () {
    testWidgets('Mitglied sieht im Kalender kein „Termin anlegen“', (tester) async {
      await _openCalendarFromShell(tester, 'member');

      expect(find.text('Kalender'), findsWidgets);
      expect(find.byKey(const Key('kalender-create')), findsNothing);
    });

    testWidgets('Schichtleitung sieht „Termin anlegen“', (tester) async {
      await _openCalendarFromShell(tester, 'shift_lead');

      expect(find.byKey(const Key('kalender-create')), findsOneWidget);
    });
  });
}
