import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/warn_stripe.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('Warnmarkierung nutzt die Streifenfarben (${b.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWachbuchTheme(b),
          home: const Scaffold(body: WarnStripe()),
        ),
      );
      final colors = b == Brightness.dark
          ? WachbuchColors.dark
          : WachbuchColors.light;
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(WarnStripe),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as WarnStripePainter;
      expect(painter.red, colors.stripeRed);
      expect(painter.white, colors.stripeWhite);
      expect(
        tester.getSize(find.byType(WarnStripe)).height,
        WachbuchTokens.stripeHeight,
      );
    });
  }

  testWidgets('Warnmarkierung ist für Screenreader unsichtbar', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WarnStripe())),
    );
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });
}
