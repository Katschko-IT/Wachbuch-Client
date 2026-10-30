import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Warnmarkierung – das eine Markenelement von Wachbuch Klar 2:
/// schmales Band mit Schrägstreifen in Leuchtrot und Weiß, wie am Heck
/// eines Rettungswagens. Wird nur oben in der Kopfleiste der App verwendet.
class WarnStripe extends StatelessWidget {
  const WarnStripe({
    super.key,
    this.height = WachbuchTokens.stripeHeight,
    this.stripeWidth = 8,
  });

  final double height;

  /// Breite eines Farbstreifens, horizontal gemessen.
  final double stripeWidth;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: WarnStripePainter(
            red: c.stripeRed,
            white: c.stripeWhite,
            stripeWidth: stripeWidth,
          ),
        ),
      ),
    );
  }
}

/// Zeichnet abwechselnd rote und weiße Streifen im Winkel von 45°.
class WarnStripePainter extends CustomPainter {
  const WarnStripePainter({
    required this.red,
    required this.white,
    required this.stripeWidth,
  });

  final Color red;
  final Color white;
  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = white);
    final paint = Paint()
      ..color = red
      ..isAntiAlias = true;
    final h = size.height;
    // Parallelogramme von links unten nach rechts oben (wie -45° im Web).
    for (var x = -h; x < size.width + h; x += stripeWidth * 2) {
      final path = Path()
        ..moveTo(x, h)
        ..lineTo(x + stripeWidth, h)
        ..lineTo(x + stripeWidth + h, 0)
        ..lineTo(x + h, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WarnStripePainter oldDelegate) =>
      oldDelegate.red != red ||
      oldDelegate.white != white ||
      oldDelegate.stripeWidth != stripeWidth;
}
