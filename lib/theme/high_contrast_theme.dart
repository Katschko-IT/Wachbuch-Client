import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';

/// Hochkontrast-Varianten von Wachbuch Klar 2 (Systemeinstellung
/// „Kontrast erhöhen“): Schwarz/Weiß, kräftige Ränder, größere Schrift.
/// Zustandsfarben (danger/warning/success) bleiben aus den Tokens.
class HighContrastTheme {
  HighContrastTheme._();

  static ThemeData light() => _build(
    WachbuchColors.highContrastLight,
    Brightness.light,
  );

  static ThemeData dark() => _build(
    WachbuchColors.highContrastDark,
    Brightness.dark,
  );

  static ThemeData _build(WachbuchColors c, Brightness brightness) {
    final base = buildWachbuchThemeFrom(c, brightness);
    final t = base.textTheme;
    final strongBorder = BorderSide(color: c.text, width: 2);
    return base.copyWith(
      textTheme: t.copyWith(
        bodySmall: t.bodySmall?.copyWith(
          fontSize: WachbuchTokens.textBody,
          color: c.text,
        ),
        bodyMedium: t.bodyMedium?.copyWith(
          fontSize: WachbuchTokens.textBody + 2,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: WachbuchTokens.textTitle),
        titleSmall: t.titleSmall?.copyWith(fontSize: WachbuchTokens.textTitle),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: WachbuchTokens.textHeadline,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontSize: WachbuchTokens.textHeadline + 4,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, WachbuchTokens.touchTarget),
          elevation: 0,
          backgroundColor: c.brand,
          foregroundColor: c.onPrimary,
          textStyle: const TextStyle(
            fontFamily: WachbuchTokens.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(WachbuchTokens.touchTarget),
          foregroundColor: c.text,
          side: strongBorder,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
          side: BorderSide(color: c.text),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: c.text,
        foregroundColor: c.surface,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: c.surface,
        ),
        shape: const Border(),
      ),
    );
  }
}
