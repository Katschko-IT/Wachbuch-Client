import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';

/// Yellow band shown while the offline demo profile is active.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    required this.visible,
    required this.label,
    this.serviceLabel,
  });

  final bool visible;
  final String label;
  final String? serviceLabel;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final text = serviceLabel == null || serviceLabel!.isEmpty
        ? label
        : '$label · $serviceLabel';
    final c = WachbuchColors.of(context);
    return Material(
      color: c.warningSoft,
      shape: Border(bottom: BorderSide(color: c.warningAccent, width: 2)),
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WachbuchTokens.space4,
            vertical: WachbuchTokens.space2,
          ),
          child: Row(
            children: [
              Icon(Icons.science_outlined, color: c.warning),
              const SizedBox(width: WachbuchTokens.space3),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: c.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: WachbuchTokens.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
