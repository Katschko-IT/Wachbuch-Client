import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/state/defect_state.dart';

import 'test_localization.dart';

const _base = 'https://wache.example.org';

/// Künftige Antwortform von GET /api/v1/defects/ (limit/offset/active).
Map<String, dynamic> _page(List<int> ids, {String? next, int count = 3}) => {
      'ok': true,
      'count': count,
      'results': [
        for (final id in ids)
          {'id': id, 'title': 'Mangel $id', 'status': 'open', 'priority': 'normal'},
      ],
      'next': next,
      'previous': null,
    };

class _PagingApi extends WachbuchApi {
  _PagingApi() : super(baseUrl: _base, token: 'wb_test');

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> me() async => {
        'membership': {'role': 'shift_lead'},
      };

  @override
  Future<DefectPage> defectsPage({bool includeDone = false, int limit = 100}) async {
    calls.add('page:${includeDone ? 'all' : 'active'}');
    return DefectPage(
      items: [
        const Defect(id: 1, title: 'Defi-Akku', priority: 'urgent'),
        if (includeDone)
          const Defect(id: 9, title: 'Alter Mangel', status: 'done'),
      ],
      count: includeDone ? 3 : 2,
      next: '/api/v1/defects/?active=1&limit=1&offset=1',
    );
  }

  @override
  Future<DefectPage> defectsNext(String next) async {
    calls.add('next:$next');
    return const DefectPage(
      items: [Defect(id: 2, title: 'Trage quietscht')],
      count: 2,
    );
  }

  @override
  Future<List<DefectAttachment>> defectAttachments(int defectId) async => const [];
}

void main() {
  group('API', () {
    test('lädt standardmäßig aktive Mängel mit limit', () async {
      late Uri requested;
      final api = WachbuchApi(
        baseUrl: _base,
        token: 'wb_test',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode(_page([1, 2], next: '/api/v1/defects/?active=1&limit=2&offset=2')),
            200,
          );
        }),
      );

      final page = await api.defectsPage(limit: 2);

      expect(requested.path, '/api/v1/defects/');
      expect(requested.queryParameters, {'active': '1', 'limit': '2'});
      expect(page.items.map((d) => d.id), [1, 2]);
      expect(page.count, 3);
      expect(page.next, '/api/v1/defects/?active=1&limit=2&offset=2');
      expect(page.hasMore, isTrue);
    });

    test('„Erledigte anzeigen“ lässt active weg', () async {
      late Uri requested;
      final api = WachbuchApi(
        baseUrl: _base,
        token: 'wb_test',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode(_page([1])), 200);
        }),
      );

      await api.defectsPage(includeDone: true);

      expect(requested.queryParameters, {'limit': '100'});
    });

    test('folgt dem relativen next-Pfad samt Query', () async {
      late Uri requested;
      final api = WachbuchApi(
        baseUrl: _base,
        token: 'wb_test',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode(_page([3])), 200);
        }),
      );

      final page = await api.defectsNext('/api/v1/defects/?active=1&limit=2&offset=2');

      expect(requested.toString(), '$_base/api/v1/defects/?active=1&limit=2&offset=2');
      expect(page.items.single.id, 3);
      expect(page.hasMore, isFalse);
    });

    test('next zu fremdem Host oder Pfad wird abgelehnt', () async {
      var calls = 0;
      final api = WachbuchApi(
        baseUrl: _base,
        token: 'wb_test',
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(_page([])), 200);
        }),
      );

      await expectLater(
        api.defectsNext('https://boese.example.com/api/v1/defects/?offset=2'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.defectsNext('/api/v1/token/'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
    });

    test('ältere Server ohne count/next liefern eine einzelne Seite', () async {
      final api = WachbuchApi(
        baseUrl: _base,
        token: 'wb_test',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'ok': true,
                'results': [
                  {'id': 4, 'title': 'X'},
                ],
              }),
              200,
            )),
      );

      final page = await api.defectsPage();

      expect(page.count, 1);
      expect(page.next, isNull);
    });
  });

  group('DefectState', () {
    test('lädt aktive Mängel, folgt next und blendet Erledigte zu', () async {
      final api = _PagingApi();
      final state = DefectState(api: api);

      await state.reload();
      expect(state.items.map((d) => d.id), [1]);
      expect(state.hasMore, isTrue);
      expect(state.totalCount, 2);

      await state.loadMore();
      expect(state.items.map((d) => d.id), [1, 2]);
      expect(state.hasMore, isFalse);

      await state.setShowDone(true);
      expect(state.showDone, isTrue);
      expect(state.items.map((d) => d.id), [1, 9]);
      expect(api.calls, [
        'page:active',
        'next:/api/v1/defects/?active=1&limit=1&offset=1',
        'page:all',
      ]);
      state.dispose();
    });
  });

  group('Mängel-Bildschirm', () {
    testWidgets('„Mehr laden“ und „Erledigte anzeigen“', (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _PagingApi();

      await tester.pumpWidget(localizedApp(home: DefectsScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Defi-Akku'), findsOneWidget);
      expect(find.text('Alter Mangel'), findsNothing);

      final more = find.byKey(const Key('defects-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Trage quietscht'), findsOneWidget);
      expect(find.byKey(const Key('defects-load-more')), findsNothing);

      await tester.tap(find.byKey(const Key('defects-show-done')));
      await tester.pumpAndSettle();
      expect(find.text('Alter Mangel'), findsOneWidget);
      expect(api.calls.last, 'page:all');
    });
  });
}
