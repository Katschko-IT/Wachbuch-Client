import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';

import 'test_localization.dart';

/// Antwortform von `_handover_json(detail=True)` in core/api/views.py.
Map<String, dynamic> _detail({String status = 'open'}) => {
      'ok': true,
      'id': 12,
      'title': 'Sauerstoff RTW 2 tauschen',
      'category': 'vehicle',
      'priority': 'important',
      'status': status,
      'updated_at': '2026-10-24T10:00:00+00:00',
      'details': 'Flasche unter 50 bar.',
      'created_at': '2026-10-24T10:00:00+00:00',
      'author': {'id': 7, 'username': 'michael', 'display_name': 'Michael K'},
      'version': status == 'open' ? 1 : 2,
    };

class _HandoverApi extends WachbuchApi {
  _HandoverApi(this.role)
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final String role;
  final created = <Map<String, String>>[];
  final statusChanges = <String>[];
  var handoverLoads = 0;

  @override
  Future<Map<String, dynamic>> me() async => {
        'user': {'id': 7, 'username': 'michael'},
        'membership': {
          'role': role,
          'role_label': role,
          'station': {'name': 'Wache Nord', 'modules': <String, dynamic>{}},
        },
      };

  @override
  Future<List<Map<String, dynamic>>> handovers() async {
    handoverLoads++;
    return [
      {
        'id': 12,
        'title': 'Sauerstoff RTW 2 tauschen',
        'category': 'vehicle',
        'priority': 'important',
        'status': 'open',
        'updated_at': '2026-10-24T10:00:00+00:00',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> handoverDetail(int id) async => _detail();

  @override
  Future<List<HandoverAck>> handoverAcks(int id) async => const [];

  @override
  Future<Map<String, dynamic>> createHandover({
    required String title,
    required String details,
    required String category,
    String priority = 'normal',
  }) async {
    created.add({
      'title': title,
      'details': details,
      'category': category,
      'priority': priority,
    });
    return _detail();
  }

  @override
  Future<Map<String, dynamic>> setHandoverStatus(int id, String status) async {
    statusChanges.add('$id:$status');
    return _detail(status: status);
  }
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openHandovers(WidgetTester tester, WachbuchApi api) async {
  await tester.pumpWidget(
    localizedApp(
      home: HomeShell(
        api: api,
        onLogout: () async {},
        onChangeServer: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Übergaben'));
  await tester.pumpAndSettle();
}

void main() {
  group('API', () {
    test('createHandover sendet die Felder von HandoverForm ohne Wiederholung',
        () async {
      final requests = <http.Request>[];
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_detail()), 201);
        }),
      );

      final result = await api.createHandover(
        title: 'Sauerstoff RTW 2 tauschen',
        details: 'Flasche unter 50 bar.',
        category: 'vehicle',
        priority: 'important',
      );

      expect(result['id'], 12);
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/v1/handovers/');
      expect(jsonDecode(requests.single.body), {
        'title': 'Sauerstoff RTW 2 tauschen',
        'details': 'Flasche unter 50 bar.',
        'category': 'vehicle',
        'priority': 'important',
      });
    });

    test('createHandover wiederholt bei 5xx nicht automatisch', () async {
      var calls = 0;
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"ok":false,"error":"kaputt"}', 503);
        }),
      );

      await expectLater(
        api.createHandover(title: 't', details: 'd', category: 'task'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    });

    test('setHandoverStatus postet den Status einmalig', () async {
      final requests = <http.Request>[];
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"ok":false,"error":"weg"}', 502);
        }),
      );

      await expectLater(
        api.setHandoverStatus(12, 'done'),
        throwsA(isA<ApiException>()),
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v1/handovers/12/status/');
      expect(jsonDecode(requests.single.body), {'status': 'done'});
    });
  });

  group('Übergaben-Tab', () {
    testWidgets('Mitglied kann anlegen, aber keinen Status setzen', (tester) async {
      _usePhone(tester);
      final api = _HandoverApi('member');
      await _openHandovers(tester, api);

      expect(find.byKey(const Key('handover-create')), findsOneWidget);

      await tester.tap(find.text('Sauerstoff RTW 2 tauschen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-status-done')), findsNothing);
    });

    testWidgets('Auditor sieht keine Schreibaktionen', (tester) async {
      _usePhone(tester);
      await _openHandovers(tester, _HandoverApi('auditor'));

      expect(find.byKey(const Key('handover-create')), findsNothing);
    });

    testWidgets('Übergabe anlegen sendet das Formular und lädt neu', (tester) async {
      _usePhone(tester);
      final api = _HandoverApi('member');
      await _openHandovers(tester, api);
      final loadsBefore = api.handoverLoads;

      await tester.tap(find.byKey(const Key('handover-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('handover-create-title')),
        'Tor klemmt',
      );
      await tester.enterText(
        find.byKey(const Key('handover-create-details')),
        'Hallentor 2 schließt nicht ganz.',
      );
      await tester.tap(find.byKey(const Key('handover-create-submit')));
      await tester.pumpAndSettle();

      expect(api.created.single, {
        'title': 'Tor klemmt',
        'details': 'Hallentor 2 schließt nicht ganz.',
        'category': 'station',
        'priority': 'normal',
      });
      expect(api.handoverLoads, greaterThan(loadsBefore));
      expect(find.byKey(const Key('handover-create-submit')), findsNothing);
    });

    testWidgets('Pflichtfelder werden vor dem Senden geprüft', (tester) async {
      _usePhone(tester);
      final api = _HandoverApi('member');
      await _openHandovers(tester, api);

      await tester.tap(find.byKey(const Key('handover-create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('handover-create-submit')));
      await tester.pumpAndSettle();

      expect(api.created, isEmpty);
    });

    testWidgets('Schichtleitung setzt den Status', (tester) async {
      _usePhone(tester);
      final api = _HandoverApi('shift_lead');
      await _openHandovers(tester, api);

      await tester.tap(find.text('Sauerstoff RTW 2 tauschen'));
      await tester.pumpAndSettle();
      final done = find.byKey(const Key('handover-status-done'));
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();

      expect(api.statusChanges, ['12:done']);
      expect(find.text('Version 2'), findsOneWidget);
    });
  });
}
