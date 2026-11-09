import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/screens/checklist_run_screen.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/date_time_text.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Checklisten der Wache.
///
/// Server ab 0.28 (`item_details`): Lauf mit Ergebnis je Prüfpunkt im
/// [ChecklistRunScreen], Zwischenstand der Wache fortsetzen. Ältere Server:
/// Abschluss mit einem Tipp wie in App 1.1.
class ChecklistenScreen extends StatefulWidget {
  const ChecklistenScreen({super.key, required this.api, this.role});

  final WachbuchApi api;

  /// Rolle aus `/me/`; wird an den Lauf (Absprung zu Mängeln) weitergegeben.
  final String? role;

  @override
  State<ChecklistenScreen> createState() => _ChecklistenScreenState();
}

class _ChecklistenScreenState extends State<ChecklistenScreen> {
  List<Checklist> _lists = const [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};
  int _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lists = await widget.api.checklisten();
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _lists = lists;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openRun(Checklist list) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChecklistRunScreen(
          api: widget.api,
          checklist: list,
          role: widget.role,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  /// Checkliste ohne Prüfpunkte auf einem 0.28-Server: Abschluss mit leerem
  /// `item_results` (der Server verlangt Ergebnisse nur für vorhandene Punkte).
  Future<void> _completeWithoutItems(Checklist list) async {
    if (_busy.contains(list.id)) return;
    setState(() {
      _busy.add(list.id);
      _error = null;
    });
    try {
      await widget.api.completeChecklistRun(list.id, results: const {});
      if (!mounted) return;
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(list.id));
    }
  }

  /// Abschluss mit einem Tipp für Server ohne `item_details` (vor 0.28).
  Future<void> _completeLegacy(Checklist list) async {
    if (_busy.contains(list.id)) return;
    setState(() {
      _busy.add(list.id);
      _error = null;
    });
    final optimistic = list.copyWith(
      completed: true,
      completedAt: DateTime.now(),
      items: list.items
          .map(
            (item) => ChecklistItem(
              id: item.id,
              label: item.label,
              checked: true,
              note: item.note,
            ),
          )
          .toList(growable: false),
    );
    setState(() {
      _lists = _lists
          .map((entry) => entry.id == list.id ? optimistic : entry)
          .toList(growable: false);
    });
    try {
      final updated = await widget.api.checklisteAbschluss(list.id);
      if (!mounted) return;
      setState(() {
        _lists = _lists
            .map(
              (entry) => entry.id == list.id
                  ? optimistic.copyWith(
                      completedAt: updated.completedAt,
                      completedBy: updated.completedBy.isEmpty
                          ? null
                          : updated.completedBy,
                      interval: updated.interval.isEmpty
                          ? null
                          : updated.interval,
                      dueNext: updated.dueNext,
                      overdue: updated.overdue,
                    )
                  : entry,
            )
            .toList(growable: false);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _lists = _lists
            .map((entry) => entry.id == list.id ? list : entry)
            .toList(growable: false);
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lists = _lists
            .map((entry) => entry.id == list.id ? list : entry)
            .toList(growable: false);
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _busy.remove(list.id));
      }
    }
  }

  Future<void> _start(Checklist list) {
    if (list.supportsItemResults) return _openRun(list);
    if (list.hasItemDetails && list.items.isEmpty) {
      return _completeWithoutItems(list);
    }
    return _completeLegacy(list);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.checklistenTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _lists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          if (_lists.isEmpty && _error == null)
            EmptyState(
              icon: Icons.checklist_outlined,
              title: AppLocalizations.of(context)!.checklistenEmptyTitle,
              message: AppLocalizations.of(context)!.checklistenEmpty,
              actionLabel: AppLocalizations.of(context)!.refreshTooltip,
              onAction: _reload,
            )
          else ...[
            if (_dueLists.isNotEmpty) ...[
              Text(
                AppLocalizations.of(context)!.checklistDueSection,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final list in _dueLists) ...[
                _ChecklistCard(
                  list: list,
                  busy: _busy.contains(list.id),
                  onStart: () => _start(list),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            for (final list in _otherLists) ...[
              _ChecklistCard(
                list: list,
                busy: _busy.contains(list.id),
                onStart: () => _start(list),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  List<Checklist> get _dueLists => _lists
      .where((list) => !list.completed && (list.isDueToday || list.overdue))
      .toList();

  List<Checklist> get _otherLists => _lists
      .where((list) => list.completed || (!list.isDueToday && !list.overdue))
      .toList();
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.list,
    required this.busy,
    required this.onStart,
  });

  final Checklist list;
  final bool busy;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final c = WachbuchColors.of(context);
    final draft = list.draft;
    final perItem = list.supportsItemResults;
    final german = Localizations.localeOf(context).languageCode == 'de';
    return Card(
      key: Key('checklist-${list.id}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  list.completed ? Icons.task_alt : Icons.checklist,
                  color: list.completed
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    list.title.isNotEmpty ? list.title : l.checklistFallback,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (list.items.isNotEmpty)
                  Chip(
                    label: Text(
                      list.hasItemDetails
                          ? l.checklistItemCount(list.items.length)
                          : '${list.checkedCount}/${list.items.length}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (list.isRecurring || list.overdue || list.isDueToday) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (list.interval == 'daily')
                    Chip(label: Text(l.checklistIntervalDaily)),
                  if (list.interval == 'weekly')
                    Chip(label: Text(l.checklistIntervalWeekly)),
                  if (list.interval == 'monthly')
                    Chip(label: Text(l.checklistIntervalMonthly)),
                  if (list.overdue)
                    Chip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: Text(l.checklistOverdue),
                      backgroundColor: scheme.errorContainer,
                    )
                  else if (list.isDueToday)
                    Chip(label: Text(l.checklistDueToday)),
                ],
              ),
            ],
            if (list.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                list.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (list.items.isEmpty)
              Text(
                l.checklistNoItems,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else if (list.hasItemDetails)
              for (final item in list.items)
                _DetailItemTile(item: item, german: german)
            else
              for (final item in list.items) _ChecklistItemTile(item: item),
            if (draft != null) ...[
              const SizedBox(height: 8),
              Row(
                key: Key('checklist-draft-${list.id}'),
                children: [
                  Icon(Icons.history, size: 20, color: c.brandDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.checklistDraftInfo(
                        draft.updatedAt == null
                            ? '—'
                            : formatDateTimeShort(context, draft.updatedAt!),
                        draft.updatedBy.isEmpty ? '—' : draft.updatedBy,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (list.completed && list.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  [
                    l.checklistCompletedAt(
                      list.completedBy.isEmpty
                          ? _formatTimestamp(list.completedAt!)
                          : '${_formatTimestamp(list.completedAt!)} · ${list.completedBy}',
                    ),
                    if (list.lastCompletedPaperBackfill)
                      l.checklistPaperBackfillMarker,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!list.completed || perItem || draft != null)
              _StartButton(list: list, busy: busy, onPressed: onStart),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.list,
    required this.busy,
    required this.onPressed,
  });

  final Checklist list;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label = !list.supportsItemResults
        ? l.checklistCompleteButton
        : list.draft != null
        ? l.checklistRunResume
        : list.completed
        ? l.checklistRunAgain
        : l.checklistRunStart;
    final icon = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            list.supportsItemResults
                ? Icons.fact_check_outlined
                : Icons.check_circle_outline,
          );
    final button = list.completed && list.draft == null
        ? OutlinedButton.icon(
            key: Key('checklist-start-${list.id}'),
            onPressed: busy ? null : onPressed,
            icon: icon,
            label: Text(label),
          )
        : FilledButton.icon(
            key: Key('checklist-start-${list.id}'),
            onPressed: busy ? null : onPressed,
            icon: icon,
            label: Text(label),
          );
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Prüfpunkt aus `item_details`: Text, Pflicht und Grenzwerte.
class _DetailItemTile extends StatelessWidget {
  const _DetailItemTile({required this.item, required this.german});

  final ChecklistItem item;
  final bool german;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final limits = checklistLimitsText(l, item, decimalComma: german);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.measurement ? Icons.straighten : Icons.check_box_outline_blank,
            color: scheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    item.label.isNotEmpty
                        ? item.label
                        : l.checklistItemFallback,
                    if (item.required) l.checklistRequiredBadge,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (limits.isNotEmpty)
                  Text(
                    limits,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  const _ChecklistItemTile({required this.item});

  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: item.checked ? scheme.primary : scheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label.isNotEmpty
                  ? item.label
                  : AppLocalizations.of(context)!.checklistItemFallback,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                decoration: item.checked ? TextDecoration.lineThrough : null,
                color: item.checked ? scheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, '
      '${two(date.hour)}:${two(date.minute)} Uhr';
}
