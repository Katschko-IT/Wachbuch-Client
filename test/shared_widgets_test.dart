import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/ui/section_title.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildWachbuchTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('EmptyState zeigt Icon, Titel, Text und Aktion', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.event_busy,
          title: 'Keine Termine',
          message: 'Keine anstehenden Termine.',
          actionLabel: 'Aktualisieren',
          onAction: () => tapped++,
        ),
      ),
    );
    expect(find.byIcon(Icons.event_busy), findsOneWidget);
    expect(find.text('Keine Termine'), findsOneWidget);
    expect(find.text('Keine anstehenden Termine.'), findsOneWidget);
    await tester.tap(find.text('Aktualisieren'));
    expect(tapped, 1);
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('EmptyState ohne Aktion zeigt keinen Button', (tester) async {
    await tester.pumpWidget(
      _wrap(const EmptyState(icon: Icons.inbox, title: 'Leer')),
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('SectionTitle ist als Überschrift markiert', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(const SectionTitle(icon: Icons.apps_outlined, title: 'Schnellzugriff')),
    );
    expect(
      tester.getSemantics(find.text('Schnellzugriff')),
      matchesSemantics(label: 'Schnellzugriff', isHeader: true),
    );
    handle.dispose();
  });
}
