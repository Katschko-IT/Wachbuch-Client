import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/reading_obligation.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';
import 'package:wachbuch_mobile/screens/notices_screen.dart';
import 'package:wachbuch_mobile/screens/reading_obligations_screen.dart';
import 'package:wachbuch_mobile/ui/date_time_text.dart';

import 'test_localization.dart';

/// Übergaben in der Form von `_handover_json` (Server 0.28): Liste ohne
/// `created_at`, Detail mit `created_at`, `details`, `author`, `version`.
const _backfill = {
  'id': 7,
  'title': 'Desinfektion RTW 1 nachgetragen',
  'category': 'vehicle',
  'priority': 'normal',
  'status': 'open',
  'updated_at': '2026-11-09T09:00:00+00:00',
  'is_paper_backfill': true,
  'occurred_at': '2026-11-08T21:30:00Z',
};

const _normal = {
  'id': 8,
  'title': 'Trage klemmt',
  'category': 'task',
  'priority': 'urgent',
  'status': 'open',
  'updated_at': '2026-11-09T08:00:00+00:00',
  'is_paper_backfill': false,
  'occurred_at': null,
};

class _Api extends WachbuchApi {
  _Api({this.obligations})
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final List<ReadingObligation>? obligations;

  @override
  Future<Map<String, dynamic>> me() async => {
    'user': {'id': 1, 'username': 'alex'},
    'membership': {
      'role': 'member',
      'role_label': 'Mitglied',
      'station': {'name': 'RW Nord', 'modules': {}},
    },
  };

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [_backfill, _normal];

  @override
  Future<Map<String, dynamic>> handoverDetail(int id) async => {
    ..._backfill,
    'details': 'Bogen vom Nachtdienst.',
    'created_at': '2026-11-09T09:00:00+00:00',
    'author': {'id': 1, 'username': 'alex', 'display_name': 'Alex'},
    'version': 1,
  };

  @override
  Future<List<ReadingObligation>?> readingObligations({
    bool openOnly = true,
  }) async => obligations;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Startseite zeigt die Lesepflicht nur, wenn etwas offen ist', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      localizedApp(
        home: HomeShell(
          api: _Api(
            obligations: [
              ReadingObligation.fromJson({
                'id': 5,
                'doc_number': 'DA-5',
                'title': 'Händedesinfektion',
                'revision': {'id': 11, 'version': '1.1'},
                'ack_due_date': '2026-11-01',
                'overdue': true,
                'acknowledged': false,
              }),
              ReadingObligation.fromJson({
                'id': 6,
                'doc_number': 'DA-6',
                'title': 'Funk',
                'revision': {'id': 12, 'version': '1.0'},
                'ack_due_date': '2026-12-01',
                'overdue': false,
                'acknowledged': false,
              }),
            ],
          ),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('overview-reading-obligations')),
      findsOneWidget,
    );
    expect(find.text('2 offen · 1 überfällig'), findsOneWidget);
    // Für Vorleser eine Schaltfläche mit Titel und Zähler.
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('2 offen · 1 überfällig')),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Dienstanweisungen lesen\n2 offen · 1 überfällig',
      ),
    );
    handle.dispose();

    await tester.tap(find.byKey(const Key('overview-reading-obligations')));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingObligationsScreen), findsOneWidget);
  });

  testWidgets('ohne offene Lesepflicht oder auf älterem Server kein Eintrag', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      localizedApp(
        home: HomeShell(
          api: _Api(obligations: null),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview-reading-obligations')), findsNothing);

    await tester.tap(find.byKey(const Key('open-notices')));
    await tester.pumpAndSettle();
    expect(find.byType(NoticesScreen), findsOneWidget);
  });

  testWidgets('Übergabe vom Papierbogen ist in Liste und Detail gekennzeichnet', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      localizedApp(
        home: HomeShell(
          api: _Api(),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übergaben').last);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeShell));
    final occurredText = formatDateTimeShort(
      context,
      DateTime.parse('2026-11-08T21:30:00Z'),
    );
    expect(find.byKey(const Key('handover-backfill-7')), findsOneWidget);
    expect(
      find.text('Nachtrag vom Papierbogen · Ereignis $occurredText'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('handover-backfill-8')), findsNothing);

    await tester.tap(find.text('Desinfektion RTW 1 nachgetragen'));
    await tester.pumpAndSettle();
    final recordedText = formatDateTimeShort(
      context,
      DateTime.parse('2026-11-09T09:00:00+00:00'),
    );
    expect(
      find.text(
        'Nachtrag vom Papierbogen · Ereignis $occurredText · erfasst $recordedText',
      ),
      findsOneWidget,
    );
  });

  test(
    'Offline-Cache speichert weder Nachtrag-Kennzeichen noch Ereigniszeit',
    () async {
      final cache = _MemoryCache();
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        cache: cache,
        client: MockClient((request) async {
          final body = request.url.path == '/api/v1/me/'
              ? {
                  'ok': true,
                  'user': {'id': 1, 'username': 'alex'},
                  'membership': {
                    'role': 'member',
                    'station': {'id': 1, 'name': 'RW'},
                  },
                }
              : {
                  'ok': true,
                  'count': 1,
                  'results': [_backfill],
                  'next': null,
                  'previous': null,
                };
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await api.me();
      await api.handovers();
      final cached = jsonEncode(cache.values['handovers']);
      expect(cached, isNot(contains('is_paper_backfill')));
      expect(cached, isNot(contains('occurred_at')));
      expect(cached, contains('Desinfektion RTW 1 nachgetragen'));
    },
  );
}

class _MemoryCache implements ApiCache {
  final Map<String, Map<String, dynamic>> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => values[key];

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<DateTime?> lastUpdatedAt() async => null;

  @override
  Future<DateTime?> oldestOrLatestTimestamp() async => null;
}
