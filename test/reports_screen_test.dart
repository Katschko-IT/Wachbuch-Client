import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/report_stats.dart';
import 'package:wachbuch_mobile/screens/reports_screen.dart';

import 'test_localization.dart';

/// Antwort eines Servers vor 0.26.1, der noch Mängel je Person liefert.
const _legacyReport = {
  'ok': true,
  'open_defects': 5,
  'overdue_defects': 2,
  'overdue_checks': 1,
  'assets_total': 4,
  'assets_ready': 3,
  'asset_ready_percent': 75,
  'inventory_out': 1,
  'unacknowledged_active_handovers': 0,
  'oldest_open_days': 9,
  'defects_by_owner': [
    {'owner': 'demo-schicht', 'count': 3},
    {'owner': '', 'count': 2},
  ],
};

WachbuchApi _api() => WachbuchApi(
      baseUrl: 'https://wache.example.org',
      token: 'wb_test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/reports/');
        return http.Response(
          jsonEncode(_legacyReport),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

void main() {
  testWidgets(
      'Auswertung zeigt keine Mängel je Person, auch wenn ein älterer Server '
      'defects_by_owner liefert', (tester) async {
    await tester.pumpWidget(localizedApp(home: ReportsScreen(api: _api())));
    await tester.pumpAndSettle();

    expect(find.text('demo-schicht'), findsNothing);
    expect(find.text('Offene Mängel nach Zuständigkeit'), findsNothing);
    expect(find.text('Ohne Zuständigkeit'), findsNothing);
    // Die Kennzahlen bleiben.
    expect(find.text('Offene Mängel'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
  });

  test('Kennzahlen werden gelesen, Zeilen je Person nicht gehalten', () async {
    final report = await _api().reportStats();

    expect(report, isA<WachalltagReport>());
    expect(report.openDefects, 5);
    expect(report.assetReadyPercent, 75);
  });
}
