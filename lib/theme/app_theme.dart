import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Wachbuch Klar 2: ruhige Flächen, Farbe nur für Zustand und Bedienung.
///
/// Alle Farben stammen aus [WachbuchColors] (hell/dunkel), Radien und
/// Abstände aus [WachbuchTokens]. Das Theme trägt [WachbuchColors] als
/// ThemeExtension, damit Widgets soft-/strong-/accent-Farben passend zum
/// Modus lesen können.
ThemeData buildWachbuchTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? WachbuchColors.dark
      : WachbuchColors.light;
  return buildWachbuchThemeFrom(c, brightness);
}

/// Baut ein vollständiges Theme aus einem Farbsatz (auch für Hochkontrast).
ThemeData buildWachbuchThemeFrom(WachbuchColors c, Brightness brightness) {
  final scheme = wachbuchColorScheme(c, brightness);
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: WachbuchTokens.fontFamily,
  );
  final text = _readableText(base.textTheme, c);

  final radiusSm = BorderRadius.circular(WachbuchTokens.radiusSm);
  final radiusMd = BorderRadius.circular(WachbuchTokens.radiusMd);
  final radiusLg = BorderRadius.circular(WachbuchTokens.radiusLg);
  final controlShape = RoundedRectangleBorder(borderRadius: radiusMd);
  final inputBorder = OutlineInputBorder(
    borderRadius: radiusMd,
    borderSide: BorderSide(color: c.lineStrong),
  );
  const buttonSize = Size(64, WachbuchTokens.touchTarget);
  const fullWidthButton = Size.fromHeight(WachbuchTokens.touchTarget);
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: WachbuchTokens.space4,
    vertical: WachbuchTokens.space3,
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    textTheme: text,
    extensions: [c],
    dividerColor: c.line,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.surface,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: c.line)),
      titleTextStyle: text.titleLarge?.copyWith(color: c.text),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radiusLg,
        side: BorderSide(color: c.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      constraints: const BoxConstraints(
        minHeight: WachbuchTokens.inputHeight,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.brand, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.danger, width: 2),
      ),
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.line),
      ),
      labelStyle: text.bodyMedium?.copyWith(color: c.muted),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: c.brand),
      hintStyle: text.bodyMedium?.copyWith(color: c.muted),
      helperStyle: text.bodySmall?.copyWith(color: c.muted),
      errorStyle: text.bodySmall?.copyWith(color: c.danger),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WachbuchTokens.space4,
        vertical: WachbuchTokens.space4,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: fullWidthButton,
        padding: buttonPadding,
        shape: controlShape,
        backgroundColor: c.brand,
        foregroundColor: c.onPrimary,
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        elevation: 0,
        shape: controlShape,
        backgroundColor: c.brand,
        foregroundColor: c.onPrimary,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: fullWidthButton,
        padding: buttonPadding,
        shape: controlShape,
        foregroundColor: c.brand,
        side: BorderSide(color: c.brand),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          WachbuchTokens.touchTarget,
          WachbuchTokens.touchTarget,
        ),
        shape: controlShape,
        foregroundColor: c.brand,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(
          WachbuchTokens.touchTarget,
          WachbuchTokens.touchTarget,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.brand,
      foregroundColor: c.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radiusLg),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(c.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(BorderSide(color: c.lineStrong)),
      shape: WidgetStatePropertyAll(controlShape),
      // Einzeilige Eingabe: Fließtext-Zeilenhöhe 1,5 schiebt den Text nach oben.
      textStyle: WidgetStatePropertyAll(text.bodyLarge?.copyWith(height: 1.2)),
      hintStyle: WidgetStatePropertyAll(
        text.bodyLarge?.copyWith(color: c.muted, height: 1.2),
      ),
      constraints: const BoxConstraints(
        minHeight: WachbuchTokens.inputHeight,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surface,
      selectedColor: c.accentSoft,
      checkmarkColor: c.brandDeep,
      labelStyle: text.labelLarge?.copyWith(color: c.text),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: c.brandDeep),
      side: BorderSide(color: c.lineStrong),
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: WachbuchTokens.space2,
        vertical: WachbuchTokens.space1,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, WachbuchTokens.touchTarget),
        side: BorderSide(color: c.lineStrong),
        selectedBackgroundColor: c.accentSoft,
        selectedForegroundColor: c.brandDeep,
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.muted,
      textColor: c.text,
      minTileHeight: WachbuchTokens.touchTarget,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WachbuchTokens.space4,
      ),
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 76,
      indicatorColor: c.accentSoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: radiusMd),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected ? c.brandDeep : c.muted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelMedium?.copyWith(
          color: selected ? c.brandDeep : c.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: radiusMd),
      selectedIconTheme: IconThemeData(color: c.brandDeep, size: 28),
      unselectedIconTheme: IconThemeData(color: c.muted, size: 26),
      selectedLabelTextStyle: text.labelLarge?.copyWith(color: c.brandDeep),
      unselectedLabelTextStyle: text.labelLarge?.copyWith(color: c.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radiusLg,
        side: BorderSide(color: c.line),
      ),
      titleTextStyle: text.titleLarge?.copyWith(color: c.text),
      contentTextStyle: text.bodyMedium?.copyWith(color: c.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: c.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WachbuchTokens.radiusLg),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.surface),
      actionTextColor: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text, borderRadius: radiusSm),
      textStyle: text.bodySmall?.copyWith(color: c.surface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.brand,
      linearTrackColor: c.surfaceSoft,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : c.lineStrong,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: c.lineStrong, width: 2),
      shape: RoundedRectangleBorder(borderRadius: radiusSm),
    ),
  );
}

/// ColorScheme aus den Tokens. `error` ist `danger` (eine Quelle).
ColorScheme wachbuchColorScheme(WachbuchColors c, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onPrimary,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.brandDeep,
    secondary: c.brandDeep,
    onSecondary: c.onPrimary,
    secondaryContainer: c.surfaceSoft,
    onSecondaryContainer: c.text,
    tertiary: c.warning,
    onTertiary: c.surface,
    tertiaryContainer: c.warningSoft,
    onTertiaryContainer: c.warning,
    error: c.danger,
    onError: dark ? c.dangerSoft : c.surface,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surfaceSoft,
    surfaceContainerHigh: c.surfaceSoft,
    surfaceContainerHighest: c.surfaceSoft,
    surfaceDim: c.bg,
    surfaceBright: c.surface,
    outline: c.lineStrong,
    outlineVariant: c.line,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: c.text,
    onInverseSurface: c.surface,
    inversePrimary: dark
        ? WachbuchColors.light.brand
        : WachbuchColors.dark.brand,
    surfaceTint: Colors.transparent,
  );
}

TextTheme _readableText(TextTheme base, WachbuchColors c) {
  // Zahlen in Kennzahlen, Zählern und Etiketten stehen spaltengenau.
  const tabular = WachbuchTokens.tabularFigures;
  final t = base.apply(bodyColor: c.text, displayColor: c.text);
  return t.copyWith(
    displayLarge: t.displayLarge?.copyWith(fontFeatures: tabular),
    displayMedium: t.displayMedium?.copyWith(fontFeatures: tabular),
    displaySmall: t.displaySmall?.copyWith(fontFeatures: tabular),
    headlineLarge: t.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: tabular,
    ),
    headlineMedium: t.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: tabular,
    ),
    headlineSmall: t.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
      fontFeatures: tabular,
    ),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
    titleMedium: t.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    bodySmall: t.bodySmall?.copyWith(
      fontSize: WachbuchTokens.textBody,
      height: 1.4,
      color: c.muted,
    ),
    labelLarge: t.labelLarge?.copyWith(
      fontSize: WachbuchTokens.textBody,
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    ),
    labelMedium: t.labelMedium?.copyWith(
      fontSize: WachbuchTokens.textBody,
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    ),
    labelSmall: t.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    ),
  );
}
