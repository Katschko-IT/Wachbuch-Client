import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/reading_obligation.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/date_time_text.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/server_page.dart';

/// Lesepflicht: eigene Dienstanweisungen lesen und bestätigen (Server ab
/// 0.28, `GET /api/v1/dienstanweisungen/`).
///
/// Bestätigt wird immer die Version, die die App zuletzt geladen hat
/// (`revision`); hat der Server inzwischen eine neuere, lehnt er mit 409 ab
/// und die App lädt neu. Gespeichert werden laut Server nur Person, Version
/// und Zeitpunkt.
class ReadingObligationsScreen extends StatefulWidget {
  const ReadingObligationsScreen({
    super.key,
    required this.api,
    this.openPage = openServerPageExternally,
  });

  final WachbuchApi api;
  final ServerPageOpener openPage;

  @override
  State<ReadingObligationsScreen> createState() =>
      _ReadingObligationsScreenState();
}

class _ReadingObligationsScreenState extends State<ReadingObligationsScreen> {
  List<ReadingObligation> _items = const [];
  bool _loading = true;
  bool _unsupported = false;
  bool _showAcknowledged = false;
  String? _error;
  final Set<int> _busy = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.readingObligations(
        openOnly: !_showAcknowledged,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _unsupported = items == null;
        _items = items ?? const [];
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(ReadingObligation item) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = widget.api.webPage(item.url);
    final opened = uri != null && await widget.openPage(uri);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l.sopOpenFailed)));
    }
  }

  Future<void> _acknowledge(ReadingObligation item) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.sopAckConfirmTitle),
        content: Text(l.sopAckConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('sop-ack-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, WachbuchTokens.touchTarget),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.sopAckConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy.add(item.id);
      _error = null;
    });
    try {
      await widget.api.acknowledgeReadingObligation(
        item.id,
        revisionId: item.revisionId,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.sopAckDone)));
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        setState(() => _error = l.sopAckNewerVersion);
        await _reload();
        if (mounted) setState(() => _error = l.sopAckNewerVersion);
      } else {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(l.sopScreenTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(width),
          ),
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  ErrorBanner(key: const Key('sop-error'), message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_unsupported)
                  Text(l.sopUnavailable)
                else ...[
                  SwitchListTile(
                    key: const Key('sop-show-acknowledged'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.sopShowAcknowledged),
                    value: _showAcknowledged,
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _showAcknowledged = value);
                            _reload();
                          },
                  ),
                  const SizedBox(height: 8),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    EmptyState(
                      icon: Icons.task_alt,
                      title: l.sopEmptyTitle,
                      message: l.sopEmpty,
                      actionLabel: l.refreshTooltip,
                      onAction: _reload,
                    )
                  else
                    for (final item in _items) ...[
                      _ObligationCard(
                        item: item,
                        busy: _busy.contains(item.id),
                        onOpen: item.url.isEmpty ? null : () => _open(item),
                        onAcknowledge: item.acknowledged
                            ? null
                            : () => _acknowledge(item),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObligationCard extends StatelessWidget {
  const _ObligationCard({
    required this.item,
    required this.busy,
    required this.onOpen,
    required this.onAcknowledge,
  });

  final ReadingObligation item;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final due = item.ackDueDate;
    final acknowledgedAt = item.acknowledgedAt;
    final overdue = item.overdue && !item.acknowledged;
    final heading = [
      if (item.docNumber.isNotEmpty) item.docNumber,
      item.title,
    ].join(' · ');
    return Card(
      key: Key('sop-${item.id}'),
      color: overdue ? c.dangerSoft : null,
      shape: overdue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
              side: BorderSide(color: scheme.error, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.revisionVersion.isNotEmpty)
                  Chip(
                    label: Text(l.sopRevision(item.revisionVersion)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (overdue && due != null)
                  Chip(
                    key: Key('sop-overdue-${item.id}'),
                    avatar: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    label: Text(
                      l.sopOverdue(formatDateShort(context, due)),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    backgroundColor: scheme.errorContainer,
                    visualDensity: VisualDensity.compact,
                  )
                else if (due != null && !item.acknowledged)
                  Chip(
                    label: Text(l.sopDue(formatDateShort(context, due))),
                    visualDensity: VisualDensity.compact,
                  ),
                if (item.acknowledged && acknowledgedAt != null)
                  Chip(
                    avatar: Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: c.success,
                    ),
                    label: Text(
                      l.sopAcknowledgedAt(
                        formatDateShort(context, acknowledgedAt),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (onOpen != null)
              OutlinedButton.icon(
                key: Key('sop-open-${item.id}'),
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: Text(l.sopOpenText),
              ),
            if (onAcknowledge != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: Key('sop-ack-${item.id}'),
                onPressed: busy ? null : onAcknowledge,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: Text(l.sopAcknowledge),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
