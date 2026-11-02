import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';

/// WCAG-2.x-Kontrast, hier im Test berechnet (relative Leuchtdichte).
double contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = lum(a);
  final lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('Kontrastformel stimmt an Referenzwerten', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), closeTo(1, 0.001));
  });

  group('Tokens Wachbuch Klar 2', () {
    test('Hell- und Dunkelwerte entsprechen dem Web', () {
      const l = WachbuchColors.light;
      const d = WachbuchColors.dark;
      expect(l.bg, const Color(0xFFF5F7F6));
      expect(d.bg, const Color(0xFF0D141A));
      expect(l.brand, const Color(0xFF0E4AA8));
      expect(d.brand, const Color(0xFF8DB4FF));
      expect(l.brandDeep, const Color(0xFF0A3A85));
      expect(d.brandDeep, const Color(0xFFB3CCFF));
      expect(l.lineStrong, const Color(0xFF6F7D88));
      expect(d.lineStrong, const Color(0xFF6D7C88));
      expect(l.info, l.brand);
      expect(d.info, d.brand);
      expect(l.stripeWhite, const Color(0xFFFFFFFF));
      expect(d.stripeWhite, const Color(0xFFC9D2D8));
      expect(l.focus, const Color(0xFFF2A900));
    });

    for (final entry in {
      'hell': WachbuchColors.light,
      'dunkel': WachbuchColors.dark,
    }.entries) {
      final c = entry.value;
      test('${entry.key}: text/surface ≥ 4,5:1', () {
        expect(contrast(c.text, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.text, c.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(c.muted, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: line-strong/surface ≥ 3:1', () {
        expect(contrast(c.lineStrong, c.surface), greaterThanOrEqualTo(3));
      });

      test('${entry.key}: Aktion und Zustandstexte lesbar', () {
        expect(contrast(c.onPrimary, c.brand), greaterThanOrEqualTo(4.5));
        expect(contrast(c.brand, c.surface), greaterThanOrEqualTo(4.5));
        for (final tone in WachbuchTone.values) {
          final t = c.tone(tone);
          expect(
            contrast(t.foreground, t.background),
            greaterThanOrEqualTo(4.5),
            reason: tone.name,
          );
        }
      });
    }

    test('Radien, Abstände und Touch-Ziel', () {
      expect(WachbuchTokens.radiusSm, 6);
      expect(WachbuchTokens.radiusMd, 10);
      expect(WachbuchTokens.radiusLg, 14);
      expect(
        [
          WachbuchTokens.space1,
          WachbuchTokens.space2,
          WachbuchTokens.space3,
          WachbuchTokens.space4,
          WachbuchTokens.space5,
          WachbuchTokens.space6,
          WachbuchTokens.space7,
        ],
        [4, 8, 12, 16, 24, 32, 48],
      );
      expect(WachbuchTokens.touchTarget, greaterThanOrEqualTo(48));
      expect(WachbuchTokens.textBody, greaterThanOrEqualTo(14));
    });
  });

  group('Statusbedeutung', () {
    test('Status: offen = info, in Arbeit = warning, wartend = neutral, '
        'erledigt = success, dringend = danger', () {
      expect(WachbuchTokens.statusTone('open'), WachbuchTone.info);
      expect(WachbuchTokens.statusTone('new'), WachbuchTone.info);
      expect(WachbuchTokens.statusTone('in_progress'), WachbuchTone.warning);
      expect(WachbuchTokens.statusTone('active'), WachbuchTone.warning);
      expect(WachbuchTokens.statusTone('waiting'), WachbuchTone.neutral);
      expect(WachbuchTokens.statusTone('blocked'), WachbuchTone.neutral);
      expect(WachbuchTokens.statusTone('done'), WachbuchTone.success);
      expect(WachbuchTokens.statusTone('closed'), WachbuchTone.success);
      expect(WachbuchTokens.statusTone('urgent'), WachbuchTone.danger);
      expect(WachbuchTokens.statusTone('???'), WachbuchTone.neutral);
    });

    test('Priorität: dringend = danger, wichtig = warning', () {
      expect(WachbuchTokens.priorityTone('urgent'), WachbuchTone.danger);
      expect(WachbuchTokens.priorityTone('high'), WachbuchTone.danger);
      expect(WachbuchTokens.priorityTone('important'), WachbuchTone.warning);
      expect(WachbuchTokens.priorityTone('normal'), WachbuchTone.info);
      expect(WachbuchTokens.priorityTone('done'), WachbuchTone.success);
    });

    test('Tonfarben kommen aus dem jeweiligen Modus', () {
      expect(WachbuchColors.dark.status('open').accent, const Color(0xFF8DB4FF));
      expect(WachbuchColors.light.status('open').accent, const Color(0xFF0E4AA8));
      expect(WachbuchColors.light.status('in_progress').accent,
          const Color(0xFFF2A900));
      expect(WachbuchColors.light.status('in_progress').foreground,
          const Color(0xFF8A4B00));
      expect(WachbuchColors.dark.priority('urgent').background,
          const Color(0xFF3A1714));
      expect(WachbuchColors.light.status('waiting').accent,
          WachbuchColors.light.muted);
    });
  });
}
