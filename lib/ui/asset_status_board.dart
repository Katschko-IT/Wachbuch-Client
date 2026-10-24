import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/section_title.dart';

/// Compact vehicle/device status board for the overview and asset screens.
class AssetStatusBoard extends StatelessWidget {
  const AssetStatusBoard({
    super.key,
    required this.assets,
    this.onAssetTap,
  });

  final List<StationAsset> assets;
  final ValueChanged<StationAsset>? onAssetTap;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.airport_shuttle_outlined,
          title: l.assetsBoardTitle,
        ),
        const SizedBox(height: WachbuchTokens.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 4 : 2;
            final width =
                (constraints.maxWidth - (WachbuchTokens.space2 * (columns - 1))) /
                columns;
            return Wrap(
              spacing: WachbuchTokens.space2,
              runSpacing: WachbuchTokens.space2,
              children: [
                for (final asset in assets)
                  SizedBox(
                    width: width,
                    child: _AssetCard(
                      asset: asset,
                      onTap: onAssetTap == null ? null : () => onAssetTap!(asset),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, this.onTap});

  final StationAsset asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tone = WachbuchColors.of(context).tone(switch (asset.status) {
      'ready' => WachbuchTone.success,
      'limited' => WachbuchTone.warning,
      _ => WachbuchTone.danger,
    });
    final statusLabel = switch (asset.status) {
      'ready' => l.assetStatusReady,
      'limited' => l.assetStatusLimited,
      'workshop' => l.assetStatusWorkshop,
      _ => l.assetStatusOob,
    };

    final content = Padding(
      padding: const EdgeInsets.all(WachbuchTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            asset.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: WachbuchTokens.space2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: WachbuchTokens.space2,
              vertical: WachbuchTokens.space1,
            ),
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(WachbuchTokens.radiusSm),
              border: Border.all(color: tone.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: WachbuchTokens.space2),
                Flexible(
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: tone.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (asset.note.isNotEmpty) ...[
            const SizedBox(height: WachbuchTokens.space2),
            Text(
              asset.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              label: '${asset.label}: $statusLabel',
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
