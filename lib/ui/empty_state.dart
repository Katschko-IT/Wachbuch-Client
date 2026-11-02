import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Leerer Zustand: Icon, Titel, erklärender Text und optionale Aktion.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel und onAction gehören zusammen',
       );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WachbuchTokens.space7,
        horizontal: WachbuchTokens.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: c.muted),
          ),
          const SizedBox(height: WachbuchTokens.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: c.text),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: WachbuchTokens.space2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.muted),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: WachbuchTokens.space4),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, WachbuchTokens.touchTarget),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
