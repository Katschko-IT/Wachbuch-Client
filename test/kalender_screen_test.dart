import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/screens/kalender_screen.dart';

import 'test_localization.dart';

class _KalenderApi extends WachbuchApi {
  _KalenderApi(this.entries)
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final List<KalenderEntry> entries;

  @override
  Future<List<KalenderEntry>> kalender() async => entries;
}

class _ErrorApi extends WachbuchApi {
  _ErrorApi()
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  @override
  Future<List<KalenderEntry>> kalender() async =>
      throw ApiException(503, 'Kalender nicht erreichbar.');
}

void main() {
  testWidgets('zeigt description und bereits laufende Termine vom Server', (tester) async {
    // Form von core/api/views.py (kalender): `description` (evtl. leer),
    // gefiltert nach Ende statt Beginn – laufende Termine sind enthalten.
    final now = DateTime.now().toUtc();
    final api = WachbuchApi(
      baseUrl: 'https://wache.example.org',
      token: 'wb_test',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'ok': true,
              'results': [
                {
                  'id': 3,
                  'title': 'Desinfektionsschulung',
                  'description': 'Raum 2, bitte Ausweis mitbringen',
                  'starts_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
                  'ends_at': now.add(const Duration(hours: 1)).toIso8601String(),
                },
                {
                  'id': 4,
                  'title': 'Fahrzeugpflege',
                  'description': '',
                  'starts_at': now.add(const Duration(days: 1)).toIso8601String(),
                  'ends_at': null,
                },
              ],
            }),
            200,
          )),
    );
    await tester.pumpWidget(localizedApp(home: KalenderScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Desinfektionsschulung'), findsOneWidget);
    expect(find.text('Raum 2, bitte Ausweis mitbringen'), findsOneWidget);
    expect(find.text('Fahrzeugpflege'), findsOneWidget);
  });

  testWidgets('renders app bar and upcoming entries', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: KalenderScreen(
          api: _KalenderApi([
            KalenderEntry(
              id: 1,
              title: 'RTW-Dienst',
              description: 'Frühschicht',
              startsAt: DateTime.parse('2026-08-03T06:00:00Z'),
              endsAt: DateTime.parse('2026-08-03T14:00:00Z'),
              location: 'Wache Nord',
            ),
            KalenderEntry(
              id: 2,
              title: 'Übung',
              allDay: true,
              startsAt: DateTime.parse('2026-08-05T00:00:00Z'),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kalender'), findsOneWidget);
    expect(find.text('RTW-Dienst'), findsOneWidget);
    expect(find.text('Frühschicht'), findsOneWidget);
    expect(find.text('Wache Nord'), findsOneWidget);
    expect(find.text('Übung'), findsOneWidget);
  });

  testWidgets('shows an empty state when no entries exist', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: KalenderScreen(api: _KalenderApi(const []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keine anstehenden Termine.'), findsOneWidget);
  });

  testWidgets('shows an error banner on API failure', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: KalenderScreen(api: _ErrorApi())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('nicht erreichbar'), findsOneWidget);
  });
}
