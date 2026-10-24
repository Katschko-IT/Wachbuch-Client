import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Abschnittsüberschrift mit Icon in Aktionsfarbe.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: 24, color: c.brand),
          const SizedBox(width: WachbuchTokens.space2),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
