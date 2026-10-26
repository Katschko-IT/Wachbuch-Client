import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';

import 'test_localization.dart';

class _MemberDemoApi extends DemoWachbuchApi {
  _MemberDemoApi() : super(profile: demoProfileFor(DemoService.rettungsdienst));

  @override
  Future<Map<String, dynamic>> me() async {
    final me = Map<String, dynamic>.from(profile.me);
    me['membership'] = {
      ...Map<String, dynamic>.from(me['membership'] as Map),
      'role': 'member',
    };
    return me;
  }
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openHandovers(WidgetTester tester, WachbuchApi api) async {
  await tester.pumpWidget(
    localizedApp(
      home: HomeShell(api: api, onLogout: () async {}, onChangeServer: () async {}),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Übergaben'));
  await tester.pumpAndSettle();
}

void main() {
  group('API', () {
    test('createHandover posts the server fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/handovers/');
        expect(jsonDecode(request.body), {
          'title': 'Sauerstoff RTW 2',
          'details': 'Flasche 2 fast leer',
          'category': 'material',
          'priority': 'urgent',
        });
        return http.Response(jsonEncode({'ok': true, 'id': 7, 'status': 'open'}), 201);
      });
      final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
      final created = await api.createHandover(
        title: 'Sauerstoff RTW 2',
        details: 'Flasche 2 fast leer',
        category: 'material',
        priority: 'urgent',
      );
      expect(created['id'], 7);
    });

    test('setHandoverStatus posts to the status endpoint', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/handovers/7/status/');
        expect(jsonDecode(request.body), {'status': 'done'});
        return http.Response(jsonEncode({'ok': true, 'id': 7, 'status': 'done'}), 200);
      });
      final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
      expect((await api.setHandoverStatus(7, 'done'))['status'], 'done');
    });

    test('lists follow next pages on the same server only', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add('${request.url.path}?${request.url.query}');
        final offset = request.url.queryParameters['offset'];
        if (offset == null) {
          return http.Response(jsonEncode({
            'results': [{'id': 1}],
            'next': '/api/v1/handovers/?limit=1&offset=1',
          }), 200);
        }
        if (offset == '1') {
          return http.Response(jsonEncode({
            'results': [{'id': 2}],
            'next': 'https://wache.example.org/api/v1/handovers/?limit=1&offset=2',
          }), 200);
        }
        return http.Response(jsonEncode({
          'results': [{'id': 3}],
          'next': 'https://evil.example.com/api/v1/handovers/?offset=3',
        }), 200);
      });
      final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
      final items = await api.handovers();
      expect(items.map((item) => item['id']), [1, 2, 3]);
      expect(requested, hasLength(3));
      expect(requested.every((path) => path.startsWith('/api/v1/handovers/')), isTrue);
    });

    test('nextPagePath rejects foreign hosts and non-API paths', () {
      final api = WachbuchApi(baseUrl: 'https://wache.example.org');
      expect(api.nextPagePath({'next': '/api/v1/defects/?offset=100'}), '/api/v1/defects/?offset=100');
      expect(api.nextPagePath({'next': 'https://evil.example.com/api/v1/x/'}), isNull);
      expect(api.nextPagePath({'next': 'http://wache.example.org/api/v1/x/'}), isNull);
      expect(api.nextPagePath({'next': '/admin/'}), isNull);
      expect(api.nextPagePath({'next': null}), isNull);
    });
  });

  group('UI', () {
    testWidgets('anyone can create a handover', (tester) async {
      _usePhone(tester);
      final api = _MemberDemoApi();
      await _openHandovers(tester, api);

      await tester.tap(find.byKey(const Key('handover-create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('handover-create-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Bitte einen Titel eingeben.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('handover-create-title')), 'Trage RTW 2 defekt');
      await tester.enterText(find.byKey(const Key('handover-create-details')), 'Rad links blockiert.');
      await tester.tap(find.text('Dringend').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('handover-create-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Übergabe gespeichert.'), findsOneWidget);
      expect(find.text('Trage RTW 2 defekt'), findsOneWidget);
      final created = (await api.handovers()).firstWhere((item) => item['title'] == 'Trage RTW 2 defekt');
      expect(created['priority'], 'urgent');
    });

    testWidgets('members see no status control', (tester) async {
      _usePhone(tester);
      final member = _MemberDemoApi();
      await _openHandovers(tester, member);
      final title = (await member.handovers()).first['title'] as String;
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-status')), findsNothing);
    });

    testWidgets('leads change the status; done leaves the active list', (tester) async {
      _usePhone(tester);
      final lead = DemoWachbuchApi(profile: demoProfileFor(DemoService.rettungsdienst));
      final title = (await lead.handovers()).first['title'] as String;
      await _openHandovers(tester, lead);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-status')), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byKey(const Key('handover-status')),
        matching: find.text('Erledigt'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Status: Erledigt'), findsOneWidget);
      expect((await lead.handovers()).any((item) => item['title'] == title), isFalse);
    });
  });
}
