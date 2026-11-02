import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/status_chip.dart';

void main() {
  group('StatusChip', () {
    Widget wrap(
      Widget child, {
      Locale locale = const Locale('de'),
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: Center(child: child)),
      );
    }

    testWidgets('renders open status in German', (tester) async {
      await tester.pumpWidget(wrap(const StatusChip(status: 'open')));
      expect(find.text('Offen'), findsOneWidget);
    });

    testWidgets('renders in_progress status in German', (tester) async {
      await tester.pumpWidget(wrap(const StatusChip(status: 'in_progress')));
      expect(find.text('In Arbeit'), findsOneWidget);
    });

    testWidgets('renders done status in German', (tester) async {
      await tester.pumpWidget(wrap(const StatusChip(status: 'done')));
      expect(find.text('Erledigt'), findsOneWidget);
    });

    testWidgets('renders English defaults for English locale', (tester) async {
      await tester.pumpWidget(
        wrap(const StatusChip(status: 'open'), locale: const Locale('en')),
      );
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Offen'), findsNothing);
    });

    testWidgets('renders custom label', (tester) async {
      await tester.pumpWidget(
        wrap(const StatusChip(status: 'open', label: 'Custom')),
      );
      expect(find.text('Custom'), findsOneWidget);
    });

    Color dotColor(WidgetTester tester) {
      final dot = tester.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      return (dot.decoration! as BoxDecoration).color!;
    }

    testWidgets('Punktfarbe folgt der Statusbedeutung im Dunkelmodus', (
      tester,
    ) async {
      final dark = buildWachbuchTheme(Brightness.dark);
      final expected = {
        'open': WachbuchColors.dark.info,
        'in_progress': WachbuchColors.dark.warningAccent,
        'waiting': WachbuchColors.dark.muted,
        'done': WachbuchColors.dark.success,
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(
          wrap(StatusChip(status: entry.key), theme: dark),
        );
        expect(dotColor(tester), entry.value, reason: entry.key);
      }
    });

    testWidgets('Text bleibt in Lesefarbe', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusChip(status: 'in_progress'),
          theme: buildWachbuchTheme(Brightness.light),
        ),
      );
      final text = tester.widget<Text>(find.text('In Arbeit'));
      expect(text.style?.color, WachbuchColors.light.warning);
    });
  });
}
