import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/screens/kalender_screen.dart';

import 'test_localization.dart';

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DemoWachbuchApi _demo() => DemoWachbuchApi(profile: demoProfileFor(DemoService.rettungsdienst));

void main() {
  test('createKalenderEntry sends UTC times', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/kalender/');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['title'], 'Fortbildung');
      expect(body['starts_at'], '2026-11-02T09:00:00.000Z');
      expect(body['ends_at'], '2026-11-02T11:00:00.000Z');
      return http.Response(jsonEncode({'ok': true, 'id': 3, 'title': 'Fortbildung', 'starts_at': body['starts_at']}), 201);
    });
    final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
    final entry = await api.createKalenderEntry(
      title: 'Fortbildung',
      startsAt: DateTime.utc(2026, 11, 2, 9),
      endsAt: DateTime.utc(2026, 11, 2, 11),
    );
    expect(entry.id, 3);
  });

  test('updateDefect patches only given fields and can clear the deadline', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/defects/9/');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'id': 9, 'title': 'Trage', 'priority': 'urgent', 'status': 'open'}), 200);
    });
    final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
    await api.updateDefect(9, priority: 'urgent');
    await api.updateDefect(9, description: 'Rad links', clearDue: true);
    expect(bodies, [
      {'priority': 'urgent'},
      {'description': 'Rad links', 'due_at': null},
    ]);
  });

  test('photos up to 5 MiB pass the client check', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'id': 1, 'filename': 'a.jpg', 'content_type': 'image/jpeg', 'size': 1}),
          201,
        ));
    final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
    final fourMiB = Uint8List(4 * 1024 * 1024);
    await api.uploadDefectAttachment(1, bytes: fourMiB, filename: 'a.jpg', contentType: 'image/jpeg');
    await expectLater(
      api.uploadDefectAttachment(1, bytes: Uint8List(5 * 1024 * 1024 + 1), filename: 'b.jpg', contentType: 'image/jpeg'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 413)),
    );
  });

  testWidgets('leads add a calendar event; others see no button', (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(localizedApp(home: KalenderScreen(api: _demo())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kalender-create')), findsNothing);

    final api = _demo();
    await tester.pumpWidget(localizedApp(home: KalenderScreen(api: api, canCreate: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kalender-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kalender-create-title')), 'Desinfektor-Schulung');
    await tester.tap(find.byKey(const Key('kalender-create-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Termin gespeichert.'), findsOneWidget);
    expect((await api.kalender()).any((e) => e.title == 'Desinfektor-Schulung'), isTrue);
  });

  testWidgets('defect can be edited from its detail sheet', (tester) async {
    _useTallPhone(tester);
    final api = _demo();
    final defect = (await api.defects()).first;
    await tester.pumpWidget(localizedApp(home: DefectsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(defect.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('defect-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('defect-edit-description')), 'Neu beschrieben');
    await tester.tap(find.byKey(const Key('defect-edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Mangel aktualisiert.'), findsOneWidget);
    expect(find.text('Neu beschrieben'), findsWidgets);
    expect((await api.defects()).firstWhere((d) => d.id == defect.id).description, 'Neu beschrieben');
  });
}
