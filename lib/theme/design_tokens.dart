import 'package:flutter/material.dart';

/// Wachbuch Klar 2 – gemeinsame Gestaltungsgrößen von Web-PWA und App.
///
/// Die Namen folgen den CSS-Variablen in `core/static/core/app.css` des
/// Server-Repos (Web `--brand-deep` → `brandDeep`, `--line-strong` →
/// `lineStrong`). Farben, die sich zwischen Hell und Dunkel unterscheiden,
/// stehen in [WachbuchColors] (ThemeExtension); hier liegen die
/// modusunabhängigen Größen und die Statuslogik.
class WachbuchTokens {
  WachbuchTokens._();

  /// Hausschrift (SIL OFL 1.1, Schnitte 400/600/700).
  static const String fontFamily = 'Atkinson Hyperlegible Next';

  /// Tabellarische Ziffern für Uhrzeiten, Beträge und Zähler.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // Abstände (Web --space-1 … --space-7).
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;

  // Sprechende Kurznamen derselben Skala.
  static const double spaceXs = space1;
  static const double spaceSm = space2;
  static const double spaceMd = space3;
  static const double spaceLg = space4;
  static const double spaceXl = space5;
  static const double space2Xl = space6;
  static const double space3Xl = space7;

  /// Mindestgröße für Bedienelemente (WCAG 2.5.5, Web --touch).
  static const double touchTarget = 48;

  /// Mindesthöhe für Eingabefelder.
  static const double inputHeight = 56;

  /// Breite der Warnmarkierung (Schrägstreifenband).
  static const double stripeHeight = 4;

  static const double textCaption = 12;
  static const double textBody = 14;
  static const double textTitle = 16;
  static const double textHeadline = 20;
  static const double textDisplay = 28;

  // Radien (Web --radius-sm / --radius / --radius-lg).
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);

  /// Statusbedeutung, verbindlich für Web und App:
  /// dringend = danger, offen = info, in Arbeit = warning,
  /// wartend = neutral, erledigt = success.
  static WachbuchTone statusTone(String status) {
    return switch (status) {
      'urgent' => WachbuchTone.danger,
      'open' || 'new' => WachbuchTone.info,
      'in_progress' || 'active' => WachbuchTone.warning,
      'waiting' || 'blocked' => WachbuchTone.neutral,
      'done' || 'closed' => WachbuchTone.success,
      _ => WachbuchTone.neutral,
    };
  }

  /// Priorität: dringend = danger, wichtig = warning, normal = info,
  /// erledigt = success.
  static WachbuchTone priorityTone(String priority) {
    return switch (priority) {
      'urgent' || 'high' => WachbuchTone.danger,
      'important' || 'medium' => WachbuchTone.warning,
      'done' || 'low' => WachbuchTone.success,
      _ => WachbuchTone.info,
    };
  }
}

/// Zustandstöne des Designsystems.
enum WachbuchTone { danger, info, warning, neutral, success }

/// Farben eines Tons für Etiketten und Hinweise.
///
/// [foreground] ist Lesefarbe (≥ 4,5:1 auf [background]), [accent] markiert
/// den Zustand als Punkt, [border] rahmt das Etikett.
@immutable
class WachbuchToneColors {
  const WachbuchToneColors({
    required this.foreground,
    required this.background,
    required this.accent,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color accent;
  final Color border;
}

/// Modusabhängige Farben von Wachbuch Klar 2 als ThemeExtension.
///
/// Zugriff: `WachbuchColors.of(context)`.
@immutable
class WachbuchColors extends ThemeExtension<WachbuchColors> {
  const WachbuchColors({
    required this.bg,
    required this.surface,
    required this.surfaceSoft,
    required this.text,
    required this.muted,
    required this.line,
    required this.lineStrong,
    required this.brand,
    required this.brandDeep,
    required this.accentSoft,
    required this.onPrimary,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.warningAccent,
    required this.success,
    required this.successSoft,
    required this.focus,
    required this.stripeRed,
    required this.stripeWhite,
  });

  /// Helle Werte (Web `:root`).
  static const light = WachbuchColors(
    bg: Color(0xFFF5F7F6),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFEEF2F1),
    text: Color(0xFF14212B),
    muted: Color(0xFF4D5B66),
    line: Color(0xFFD7DDE1),
    lineStrong: Color(0xFF6F7D88),
    brand: Color(0xFF0E4AA8),
    brandDeep: Color(0xFF0A3A85),
    accentSoft: Color(0xFFE3ECFA),
    onPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFB81D18),
    dangerSoft: Color(0xFFFCEBEA),
    warning: Color(0xFF8A4B00),
    warningSoft: Color(0xFFFDF2DF),
    warningAccent: Color(0xFFF2A900),
    success: Color(0xFF136B3A),
    successSoft: Color(0xFFE5F4EA),
    focus: Color(0xFFF2A900),
    stripeRed: Color(0xFFE2231A),
    stripeWhite: Color(0xFFFFFFFF),
  );

  /// Dunkle Werte für den Nachtdienst (Web `[data-theme="dark"]`).
  static const dark = WachbuchColors(
    bg: Color(0xFF0D141A),
    surface: Color(0xFF151E26),
    surfaceSoft: Color(0xFF1C2731),
    text: Color(0xFFE7ECEF),
    muted: Color(0xFFA6B3BD),
    line: Color(0xFF2B3843),
    lineStrong: Color(0xFF6D7C88),
    brand: Color(0xFF8DB4FF),
    brandDeep: Color(0xFFB3CCFF),
    accentSoft: Color(0xFF1B2D4A),
    onPrimary: Color(0xFF0A1A33),
    danger: Color(0xFFFF8F86),
    dangerSoft: Color(0xFF3A1714),
    warning: Color(0xFFFFC966),
    warningSoft: Color(0xFF33260C),
    warningAccent: Color(0xFFF2A900),
    success: Color(0xFF6FD49A),
    successSoft: Color(0xFF11301F),
    focus: Color(0xFFF2A900),
    stripeRed: Color(0xFFE2231A),
    stripeWhite: Color(0xFFC9D2D8),
  );

  /// Hoher Kontrast hell: Schwarz auf Weiß, Zustandsfarben bleiben.
  static final highContrastLight = light.copyWith(
    bg: const Color(0xFFFFFFFF),
    surfaceSoft: const Color(0xFFFFFFFF),
    text: const Color(0xFF000000),
    muted: const Color(0xFF000000),
    line: const Color(0xFF000000),
    lineStrong: const Color(0xFF000000),
    brand: const Color(0xFF000000),
    brandDeep: const Color(0xFF000000),
  );

  /// Hoher Kontrast dunkel: Weiß auf Schwarz, Zustandsfarben bleiben.
  static final highContrastDark = dark.copyWith(
    bg: const Color(0xFF000000),
    surface: const Color(0xFF000000),
    surfaceSoft: const Color(0xFF000000),
    text: const Color(0xFFFFFFFF),
    muted: const Color(0xFFFFFFFF),
    line: const Color(0xFFFFFFFF),
    lineStrong: const Color(0xFFFFFFFF),
    brand: const Color(0xFFFFFFFF),
    brandDeep: const Color(0xFFFFFFFF),
    onPrimary: const Color(0xFF000000),
  );

  final Color bg;
  final Color surface;
  final Color surfaceSoft;
  final Color text;
  final Color muted;
  final Color line;
  final Color lineStrong;

  /// Aktion „Blaulicht“: Bedienung, Auswahl, aktive Navigation.
  final Color brand;
  final Color brandDeep;
  final Color accentSoft;
  final Color onPrimary;

  final Color danger;
  final Color dangerSoft;

  /// Warnung als Textfarbe (≥ 4,5:1); Signalfläche ist [warningAccent].
  final Color warning;
  final Color warningSoft;
  final Color warningAccent;
  final Color success;
  final Color successSoft;
  final Color focus;

  /// Warnmarkierung (Markenelement).
  final Color stripeRed;
  final Color stripeWhite;

  Color get info => brand;
  Color get infoSoft => accentSoft;

  /// Farben eines Zustandstons für Etiketten (Text in Lesefarbe, Zustand als
  /// Punkt und Rand).
  WachbuchToneColors tone(WachbuchTone tone) {
    return switch (tone) {
      WachbuchTone.danger => WachbuchToneColors(
        foreground: danger,
        background: dangerSoft,
        accent: danger,
        border: danger.withValues(alpha: 0.45),
      ),
      WachbuchTone.info => WachbuchToneColors(
        foreground: text,
        background: infoSoft,
        accent: info,
        border: info.withValues(alpha: 0.45),
      ),
      WachbuchTone.warning => WachbuchToneColors(
        foreground: warning,
        background: warningSoft,
        accent: warningAccent,
        border: warningAccent.withValues(alpha: 0.7),
      ),
      WachbuchTone.neutral => WachbuchToneColors(
        foreground: text,
        background: surface,
        accent: muted,
        border: line,
      ),
      WachbuchTone.success => WachbuchToneColors(
        foreground: success,
        background: successSoft,
        accent: success,
        border: success.withValues(alpha: 0.45),
      ),
    };
  }

  WachbuchToneColors status(String status) =>
      tone(WachbuchTokens.statusTone(status));

  WachbuchToneColors priority(String priority) =>
      tone(WachbuchTokens.priorityTone(priority));

  /// Farben des aktuellen Themes; fällt auf die hellen Werte zurück, falls
  /// ein Theme ohne Erweiterung verwendet wird (z. B. in Tests).
  static WachbuchColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<WachbuchColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  WachbuchColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSoft,
    Color? text,
    Color? muted,
    Color? line,
    Color? lineStrong,
    Color? brand,
    Color? brandDeep,
    Color? accentSoft,
    Color? onPrimary,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
    Color? warningAccent,
    Color? success,
    Color? successSoft,
    Color? focus,
    Color? stripeRed,
    Color? stripeWhite,
  }) {
    return WachbuchColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      onPrimary: onPrimary ?? this.onPrimary,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      warningAccent: warningAccent ?? this.warningAccent,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      focus: focus ?? this.focus,
      stripeRed: stripeRed ?? this.stripeRed,
      stripeWhite: stripeWhite ?? this.stripeWhite,
    );
  }

  @override
  WachbuchColors lerp(covariant WachbuchColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return WachbuchColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceSoft: l(surfaceSoft, other.surfaceSoft),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      brand: l(brand, other.brand),
      brandDeep: l(brandDeep, other.brandDeep),
      accentSoft: l(accentSoft, other.accentSoft),
      onPrimary: l(onPrimary, other.onPrimary),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      warningAccent: l(warningAccent, other.warningAccent),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      focus: l(focus, other.focus),
      stripeRed: l(stripeRed, other.stripeRed),
      stripeWhite: l(stripeWhite, other.stripeWhite),
    );
  }
}
