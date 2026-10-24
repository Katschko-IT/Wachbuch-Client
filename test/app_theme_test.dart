import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/theme/high_contrast_theme.dart';

void main() {
  test('helles Theme folgt Wachbuch Klar 2', () {
    final theme = buildWachbuchTheme(Brightness.light);

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF0E4AA8));
    expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
    expect(theme.colorScheme.primaryContainer, const Color(0xFFE3ECFA));
    expect(theme.colorScheme.onSurface, const Color(0xFF14212B));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7F6));
    expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
    expect(theme.textTheme.bodySmall?.fontSize, greaterThanOrEqualTo(14));
    expect(theme.textTheme.labelMedium?.fontSize, greaterThanOrEqualTo(14));
  });

  test('dunkles Theme nutzt die Nachtdienst-Werte', () {
    final theme = buildWachbuchTheme(Brightness.dark);

    expect(theme.colorScheme.primary, const Color(0xFF8DB4FF));
    expect(theme.colorScheme.onPrimary, const Color(0xFF0A1A33));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0D141A));
    expect(theme.cardTheme.color, const Color(0xFF151E26));
    expect(theme.colorScheme.surface.a, 1.0);
  });

  test('ColorScheme.error ist danger aus den Tokens', () {
    expect(
      buildWachbuchTheme(Brightness.light).colorScheme.error,
      WachbuchColors.light.danger,
    );
    expect(
      buildWachbuchTheme(Brightness.dark).colorScheme.error,
      WachbuchColors.dark.danger,
    );
    expect(WachbuchColors.light.danger, const Color(0xFFB81D18));
  });

  test('ThemeExtension WachbuchColors ist in allen Themes vorhanden', () {
    final themes = {
      'hell': buildWachbuchTheme(Brightness.light),
      'dunkel': buildWachbuchTheme(Brightness.dark),
      'kontrast hell': HighContrastTheme.light(),
      'kontrast dunkel': HighContrastTheme.dark(),
    };
    for (final entry in themes.entries) {
      expect(
        entry.value.extension<WachbuchColors>(),
        isNotNull,
        reason: entry.key,
      );
    }
    expect(
      buildWachbuchTheme(Brightness.light).extension<WachbuchColors>(),
      same(WachbuchColors.light),
    );
    expect(
      buildWachbuchTheme(Brightness.dark).extension<WachbuchColors>(),
      same(WachbuchColors.dark),
    );
  });

  test('Hausschrift und tabellarische Ziffern', () {
    final theme = buildWachbuchTheme(Brightness.light);
    expect(theme.textTheme.bodyMedium?.fontFamily, WachbuchTokens.fontFamily);
    expect(
      theme.textTheme.headlineMedium?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      theme.textTheme.labelLarge?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('Bedienelemente haben mindestens 48 dp', () {
    final theme = buildWachbuchTheme(Brightness.light);

    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(WachbuchTokens.touchTarget),
    );
    expect(
      theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(WachbuchTokens.touchTarget),
    );
    expect(
      theme.textButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(WachbuchTokens.touchTarget),
    );
    expect(theme.inputDecorationTheme.constraints?.minHeight, 56);
  });

  test('Komponenten: Karten ohne Schatten, Eingaben mit line-strong', () {
    for (final b in Brightness.values) {
      final theme = buildWachbuchTheme(b);
      final c = theme.extension<WachbuchColors>()!;
      expect(theme.cardTheme.elevation, 0);
      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.side.color, c.line);
      expect(
        cardShape.borderRadius,
        BorderRadius.circular(WachbuchTokens.radiusLg),
      );
      final input = theme.inputDecorationTheme.enabledBorder!
          as OutlineInputBorder;
      expect(input.borderSide.color, c.lineStrong);
      expect(input.borderRadius, BorderRadius.circular(WachbuchTokens.radiusMd));
      expect(theme.navigationBarTheme.indicatorColor, c.accentSoft);
    }
  });

  test('Hochkontrast bleibt schwarz-weiß', () {
    final light = HighContrastTheme.light();
    final dark = HighContrastTheme.dark();

    expect(light.colorScheme.primary, const Color(0xFF000000));
    expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(light.colorScheme.onSurface, const Color(0xFF000000));
    expect(dark.colorScheme.primary, const Color(0xFFFFFFFF));
    expect(dark.colorScheme.surface, const Color(0xFF000000));
    expect(dark.colorScheme.onSurface, const Color(0xFFFFFFFF));
    expect(
      light.elevatedButtonTheme.style?.minimumSize?.resolve({})?.height,
      WachbuchTokens.touchTarget,
    );
  });
}
