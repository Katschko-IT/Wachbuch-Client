import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';

/// Karte zur Anzeige des Offline-Cache-Alters und Aktion „Offline-Daten löschen“
/// gemäß Offline-Vertrag §6.4/§6.5.
class OfflineCacheCard extends StatefulWidget {
  const OfflineCacheCard({
    super.key,
    this.apiCache,
    this.clock,
    this.onCleared,
  });

  final ApiCache? apiCache;
  final DateTime Function()? clock;
  final VoidCallback? onCleared;

  @override
  State<OfflineCacheCard> createState() => _OfflineCacheCardState();
}

class _OfflineCacheCardState extends State<OfflineCacheCard> {
  DateTime? _lastUpdatedAt;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant OfflineCacheCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiCache != widget.apiCache) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final cache = widget.apiCache;
    if (cache == null) {
      if (mounted) {
        setState(() {
          _lastUpdatedAt = null;
        });
      }
      return;
    }
    final ts = await cache.lastUpdatedAt();
    if (mounted) {
      setState(() {
        _lastUpdatedAt = ts;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      await widget.apiCache?.clear();
    } finally {
      if (mounted) {
        setState(() {
          _lastUpdatedAt = null;
          _clearing = false;
        });
        final l = AppLocalizations.of(context);
        final msg = l?.offlineCacheCleared ?? 'Offline-Daten wurden gelöscht.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        widget.onCleared?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final german = Localizations.localeOf(context).languageCode == 'de';

    final statusText = _lastUpdatedAt == null
        ? (l?.offlineCacheEmpty ?? 'Keine Offline-Daten gespeichert')
        : formatOfflineCacheStatus(
            _lastUpdatedAt,
            now: widget.clock?.call(),
            isGerman: german,
          );

    final clearLabel = l?.offlineCacheClear ?? 'Offline-Daten löschen';

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastUpdatedAt == null
                      ? Icons.cloud_done_outlined
                      : Icons.offline_pin_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    key: const Key('offline-cache-status-text'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('clear-offline-cache-button'),
              onPressed: _clearing ? null : _clearCache,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(clearLabel),
            ),
          ],
        ),
      ),
    );
  }
}
