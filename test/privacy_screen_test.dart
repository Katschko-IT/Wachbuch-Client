import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/screens/privacy_screen.dart';

import 'test_localization.dart';

void main() {
  testWidgets('privacy policy renders German store copy and public link', (
    tester,
  ) async {
    await tester.pumpWidget(localizedApp(home: const PrivacyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Datenschutz'), findsOneWidget);
    expect(find.textContaining('keine zentrale Wachwerk-Cloud'), findsOneWidget);
    // Offline-Vertrag: 24 h, Positivliste, Rollenausschluss.
    expect(find.textContaining('höchstens 24 Stunden'), findsOneWidget);
    expect(
      find.textContaining('Für Master-Admin, Kassenwart und Auditor gibt es '
          'keinen Offline-Cache'),
      findsOneWidget,
    );
    expect(find.textContaining('Übergabeliste ohne Freitext'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Ich habe bezahlt'),
      300,
    );
    expect(find.textContaining('Gelesen-Status persönlicher Hinweise'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-privacy-policy')),
      300,
    );
    expect(find.byKey(const Key('open-privacy-policy')), findsOneWidget);
    expect(find.textContaining('PRIVACY-POLICY.md'), findsOneWidget);
  });

  testWidgets('privacy policy renders English store copy and public link', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        home: const PrivacyScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.textContaining('open-source client'), findsOneWidget);
    expect(find.textContaining('for at most 24 hours'), findsOneWidget);
    expect(
      find.textContaining('no offline cache for master admins, treasurers and '
          'auditors'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('I have paid'),
      300,
    );
    expect(find.textContaining('read status of personal notices'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-privacy-policy')),
      300,
    );
    expect(find.byKey(const Key('open-privacy-policy')), findsOneWidget);
    expect(find.text('Open privacy policy'), findsOneWidget);
  });
}
