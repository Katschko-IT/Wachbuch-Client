import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';

/// Produktgrenze an Freitextfeldern: keine Patienten- oder Einsatzdaten.
///
/// Entspricht dem Hinweis des Web-Formulars (`templates/core/handover_form.html`
/// im Server-Repository). Steht direkt unter der Überschrift, damit er vor
/// dem Tippen sichtbar ist.
class FreeTextBoundaryHint extends StatelessWidget {
  const FreeTextBoundaryHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      key: const Key('free-text-boundary-hint'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.freeTextBoundaryHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
