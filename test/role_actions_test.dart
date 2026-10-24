import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/assets_screen.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
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
  Future<List<Defect>> defects() async => const [
        Defect(id: 1, title: 'Trage quietscht'),
      ];

  @override
  Future<List<DefectAttachment>> defectAttachments(int defectId) async => const [];
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
  });
}
