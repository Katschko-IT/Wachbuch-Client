import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/crew_notice.dart';
import 'package:wachbuch_mobile/models/reading_obligation.dart';
import 'package:wachbuch_mobile/screens/notices_screen.dart';
import 'package:wachbuch_mobile/screens/reading_obligations_screen.dart';

import 'test_localization.dart';

/// Antwortform von `core/api/sop.py` (`_sop_json`) im Server 0.28.
Map<String, dynamic> _sop({
  int id = 5,
  int revision = 11,
  String version = '1.1',
  bool overdue = false,
  bool acknowledged = false,
}) => {
  'id': id,
  'doc_number': 'DA-$id',
  'title': 'Händedesinfektion',
  'revision': {'id': revision, 'version': version},
  'ack_due_date': '2026-11-01',
  'overdue': overdue,
  'acknowledged': acknowledged,
  'acknowledged_at': acknowledged ? '2026-11-09T07:00:00+00:00' : null,
  'in_target_group': true,
  'url': '/orga/sop/da-$id/',
};

class _SopApi extends WachbuchApi {
  _SopApi({
    required this.items,
    this.conflictOnce = false,
    this.archivedOnce = false,
    this.supported = true,
  }) : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  List<Map<String, dynamic>> items;
  bool conflictOnce;

  /// Zwischen Liste und Bestätigen außer Kraft gesetzt (auch 409).
  bool archivedOnce;
  final bool supported;
  final acks = <(int, int?)>[];
  final openOnlyCalls = <bool>[];
  final readIds = <int>[];
  List<CrewNotice> notices = const [];

  @override
  Future<List<ReadingObligation>?> readingObligations({
    bool openOnly = true,
  }) async {
    openOnlyCalls.add(openOnly);
    if (!supported) return null;
    return items
        .where((item) => !openOnly || item['acknowledged'] != true)
        .map(ReadingObligation.fromJson)
        .toList();
  }

  @override
  Future<ReadingObligation> acknowledgeReadingObligation(
    int id, {
    int? revisionId,
  }) async {
    acks.add((id, revisionId));
    if (archivedOnce) {
      archivedOnce = false;
      items = [];
      throw ApiException(
        409,
        'Diese Dienstanweisung ist außer Kraft und kann nicht mehr quittiert werden.',
        code: 'conflict',
      );
    }
    if (conflictOnce) {
      conflictOnce = false;
      // Inzwischen gibt es Version 1.2.
      items = [_sop(id: id, revision: 12, version: '1.2')];
      throw ApiException(
        409,
        'Es gibt eine neuere Version dieser Dienstanweisung.',
        code: 'conflict',
      );
    }
    items = [
      for (final item in items)
        if (item['id'] == id)
          {
            ...item,
            'acknowledged': true,
            'acknowledged_at': '2026-11-09T08:00:00+00:00',
          }
        else
          item,
    ];
    return ReadingObligation.fromJson(
      items.firstWhere((item) => item['id'] == id),
    );
  }

  @override
  Future<List<CrewNotice>> crewNotices() async => notices;

  @override
  Future<void> markCrewNoticeRead(int id) async => readIds.add(id);
}

void main() {
  group('API', () {
    test(
      'Liste ?offen=1, Bestätigen mit revision, ältere Server ohne Endpunkt',
      () async {
        final requests = <http.Request>[];
        var status = 200;
        final api = WachbuchApi(
          baseUrl: 'https://wache.example.org',
          token: 'wb_test',
          client: MockClient((request) async {
            requests.add(request);
            if (status != 200) return http.Response('{}', status);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'count': 1,
                  'results': [_sop(overdue: true)],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'ok': true,
                'created': true,
                ..._sop(acknowledged: true),
              }),
              201,
            );
          }),
        );

        final open = await api.readingObligations();
        expect(
          requests.single.url.toString(),
          'https://wache.example.org/api/v1/dienstanweisungen/?offen=1',
        );
        final item = open!.single;
        expect(item.docNumber, 'DA-5');
        expect(item.revisionId, 11);
        expect(item.revisionVersion, '1.1');
        expect(item.ackDueDate, DateTime(2026, 11, 1));
        expect(item.overdue, isTrue);
        expect(item.isOpen, isTrue);

        final acked = await api.acknowledgeReadingObligation(5, revisionId: 11);
        expect(acked.acknowledged, isTrue);
        expect(requests.last.method, 'POST');
        expect(
          requests.last.url.path,
          '/api/v1/dienstanweisungen/5/quittieren/',
        );
        expect(jsonDecode(requests.last.body), {'revision': 11});

        status = 404;
        expect(await api.readingObligations(), isNull);
      },
    );

    test('409 bei neuerer Version kommt als ApiException an', () async {
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'ok': false,
              'error': {
                'code': 'conflict',
                'message':
                    'Es gibt eine neuere Version dieser Dienstanweisung.',
                'correlation_id': 'x',
              },
            }),
            409,
          ),
        ),
      );
      await expectLater(
        api.acknowledgeReadingObligation(5, revisionId: 11),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('webPage öffnet nur Pfade auf dem eigenen Server', () {
      final api = WachbuchApi(baseUrl: 'https://wache.example.org:8443');
      expect(
        api.webPage('/orga/sop/da-5/').toString(),
        'https://wache.example.org:8443/orga/sop/da-5/',
      );
      expect(api.webPage('https://fremd.example.org/x'), isNull);
      expect(api.webPage('//fremd.example.org/x'), isNull);
      expect(api.webPage(''), isNull);
    });
  });

  testWidgets('Lesepflicht: überfällig markiert, Bestätigen mit Version', (
    tester,
  ) async {
    final api = _SopApi(items: [_sop(overdue: true)]);
    final opened = <Uri>[];
    await tester.pumpWidget(
      localizedApp(
        home: ReadingObligationsScreen(
          api: api,
          openPage: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DA-5 · Händedesinfektion'), findsOneWidget);
    expect(find.text('Version 1.1'), findsOneWidget);
    expect(find.byKey(const Key('sop-overdue-5')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sop-open-5')));
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'https://wache.example.org/orga/sop/da-5/',
    );

    await tester.tap(find.byKey(const Key('sop-ack-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sop-ack-confirm')));
    await tester.pumpAndSettle();

    expect(api.acks.single, (5, 11));
    expect(find.text('Lesebestätigung gespeichert.'), findsOneWidget);
    expect(find.text('Alles gelesen'), findsOneWidget);
  });

  testWidgets(
    'Lesepflicht: neuere Version (409) lädt neu und bestätigt nichts still',
    (tester) async {
      final api = _SopApi(items: [_sop()], conflictOnce: true);
      await tester.pumpWidget(
        localizedApp(home: ReadingObligationsScreen(api: api)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sop-ack-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sop-ack-confirm')));
      await tester.pumpAndSettle();

      expect(api.acks.single, (5, 11));
      expect(
        find.text(
          'Es gibt eine neuere Version. Bitte zuerst die aktuelle Fassung lesen.',
        ),
        findsOneWidget,
      );
      expect(find.text('Version 1.2'), findsOneWidget);
    },
  );

  testWidgets(
    'Lesepflicht: 409 „außer Kraft“ zeigt die Meldung des Servers, nicht „neuere Version“',
    (tester) async {
      final api = _SopApi(items: [_sop()], archivedOnce: true);
      await tester.pumpWidget(
        localizedApp(home: ReadingObligationsScreen(api: api)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sop-ack-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sop-ack-confirm')));
      await tester.pumpAndSettle();

      expect(api.acks.single, (5, 11));
      expect(
        find.text(
          'Diese Dienstanweisung ist außer Kraft und kann nicht mehr quittiert werden.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Es gibt eine neuere Version. Bitte zuerst die aktuelle Fassung lesen.',
        ),
        findsNothing,
      );
      expect(find.text('Alles gelesen'), findsOneWidget);
    },
  );

  testWidgets('Lesepflicht auf älterem Server: Hinweis statt Liste', (
    tester,
  ) async {
    final api = _SopApi(items: const [], supported: false);
    await tester.pumpWidget(
      localizedApp(home: ReadingObligationsScreen(api: api)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Dieser Server bietet Lesebestätigungen in der App erst ab Wachwerk 0.28.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Hinweise: Arten von 0.28 mit Bezeichnung, nur diese gelesen gemeldet',
    (tester) async {
      final api = _SopApi(items: [_sop()]);
      api.notices = [
        CrewNotice.fromJson({
          'id': 1,
          'kind': 'deadline_due',
          'key': 'deadline:stk:4:7:2026-11-16',
          'title': 'Frist in 7 Tagen: STK RTW 1',
          'body': 'Bitte Termin vereinbaren.',
          'url': '/fuhrpark/v/rtw-1/',
          'read': false,
          'created_at': '2026-11-09T06:00:00+00:00',
        }),
        CrewNotice.fromJson({
          'id': 2,
          'kind': 'deadline_due',
          'key': 'deadline_weekly_digest:3:2026-W46',
          'title': 'Wochenübersicht KW 46: 2 Fristen',
          'body': 'STK RTW 1 · HU KTW 2',
          'url': '/fristen/',
          'read': true,
        }),
        CrewNotice.fromJson({
          'id': 3,
          'kind': 'sop_due',
          'key': 'deadline:sop:5:7:7:2026-11-16',
          'title': 'Lesefrist Dienstanweisung DA-5',
          'body': 'Bitte bestätigen.',
          'url': '/orga/sop/da-5/',
          'read': false,
        }),
        CrewNotice.fromJson({
          'id': 4,
          'kind': 'shift_swap',
          'key': 'shift_swap:1',
          'title': 'Künftige Art',
          'body': 'x',
          'read': false,
        }),
      ];
      await tester.pumpWidget(localizedApp(home: NoticesScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Frist'), findsOneWidget);
      expect(find.text('Wochenübersicht'), findsOneWidget);
      expect(find.text('Lesefrist'), findsOneWidget);
      expect(find.text('Künftige Art'), findsNothing);
      expect(api.readIds, [1, 3]);

      await tester.tap(find.byKey(const Key('notice-3')));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingObligationsScreen), findsOneWidget);
    },
  );
}
