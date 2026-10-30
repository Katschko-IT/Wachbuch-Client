import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/screens/handover_create_sheet.dart';
import 'package:wachbuch_mobile/screens/kalender_screen.dart';
import 'package:wachbuch_mobile/state/handover_state.dart';

import 'test_localization.dart';

/// Produktgrenze (AGENTS § 1): neue Freitextformulare sagen, dass keine
/// Patienten- oder Einsatzdaten hineingehören.
const _hintDe = 'Keine Patienten- oder Einsatzdaten eintragen.';

DemoWachbuchApi _demo() =>
    DemoWachbuchApi(profile: demoProfileFor(DemoService.rettungsdienst));

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Übergabe anlegen zeigt den Hinweis', (tester) async {
    _useTallPhone(tester);
    final state = HandoverState(api: _demo());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      localizedApp(home: Scaffold(body: HandoverCreateSheet(state: state))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('free-text-boundary-hint')), findsOneWidget);
    expect(find.text(_hintDe), findsOneWidget);
  });

  testWidgets('Termin anlegen zeigt den Hinweis', (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(
      localizedApp(home: Scaffold(body: KalenderCreateSheet(api: _demo()))),
    );
    await tester.pumpAndSettle();

    expect(find.text(_hintDe), findsOneWidget);
  });

  testWidgets('Mangel bearbeiten zeigt den Hinweis', (tester) async {
    _useTallPhone(tester);
    final api = _demo();
    final defect = (await api.defects()).first;
    await tester.pumpWidget(localizedApp(home: DefectsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(defect.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('defect-edit')));
    await tester.pumpAndSettle();

    expect(find.text(_hintDe), findsOneWidget);
  });

  testWidgets('Hinweis auf Englisch', (tester) async {
    _useTallPhone(tester);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        home: Scaffold(body: KalenderCreateSheet(api: _demo())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Do not enter patient or mission data.'), findsOneWidget);
  });
}
