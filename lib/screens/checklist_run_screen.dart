import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/state/checklist_run.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/date_time_text.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/free_text_boundary_hint.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Checklisten-Lauf mit Ergebnis je Prüfpunkt (Server ab 0.28).
///
/// - Je Prüfpunkt „In Ordnung“, „Nicht in Ordnung“ oder „Entfällt“ (mit
///   Begründung); Messpunkte mit Wert, Einheit und Grenzwert-Hinweis.
/// - Schlüssel sind ausschließlich die Server-Kennungen aus `item_details`.
/// - „Zwischenstand speichern“ ersetzt den gemeinsamen Zwischenstand der
///   Wache; beim Öffnen wird er online geladen (nie aus dem Offline-Cache).
/// - Prüffehler (400 mit `errors`) erscheinen am jeweiligen Prüfpunkt; die
///   Eingaben bleiben erhalten. Bewertet wird nur auf dem Server.
///
/// Gibt `true` zurück, wenn ein Lauf abgeschlossen oder ein Zwischenstand
/// gespeichert wurde.
class ChecklistRunScreen extends StatefulWidget {
  const ChecklistRunScreen({
    super.key,
    required this.api,
    required this.checklist,
    this.role,
  });

  final WachbuchApi api;
  final Checklist checklist;

  /// Rolle aus `/me/`, für den Absprung in die Mängel.
  final String? role;

  @override
  State<ChecklistRunScreen> createState() => _ChecklistRunScreenState();
}

class _ChecklistRunScreenState extends State<ChecklistRunScreen> {
  final Map<int, String> _status = {};
  final Map<int, TextEditingController> _values = {};
  final Map<int, TextEditingController> _reasons = {};
  final TextEditingController _note = TextEditingController();

  bool _loadingDraft = true;
  String? _draftNotice;
  String? _draftError;
  bool _busy = false;
  bool _dirty = false;
  bool _changedOnServer = false;
  String? _error;
  ChecklistErrorAssignment _errors = const ChecklistErrorAssignment();
  ChecklistRunResult? _result;

  List<ChecklistItem> get _items => [
    for (final item in widget.checklist.items)
      if (item.serverId != null) item,
  ];

  @override
  void initState() {
    super.initState();
    for (final item in _items) {
      final id = item.serverId!;
      _values[id] = TextEditingController()..addListener(_markDirty);
      _reasons[id] = TextEditingController()..addListener(_markDirty);
    }
    _note.addListener(_markDirty);
    _loadDraft();
  }

  @override
  void dispose() {
    for (final controller in [..._values.values, ..._reasons.values, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _loadDraft() async {
    setState(() {
      _loadingDraft = true;
      _draftError = null;
    });
    try {
      final draft = await widget.api.checklistDraft(widget.checklist.id);
      if (!mounted) return;
      if (draft != null) _applyDraft(draft);
      setState(() {
        _loadingDraft = false;
        _dirty = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDraft = false;
        // Ältere Server ohne Zwischenstand: einfach frisch beginnen.
        _draftError = WachbuchApi.isModuleUnavailable(error)
            ? null
            : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDraft = false;
        _draftError = error.toString();
      });
    }
  }

  void _applyDraft(ChecklistDraft draft) {
    final l = AppLocalizations.of(context)!;
    final german = Localizations.localeOf(context).languageCode == 'de';
    for (final item in _items) {
      final id = item.serverId!;
      final saved = draft.results[id];
      if (saved == null) continue;
      if (saved.status.isNotEmpty) _status[id] = saved.status;
      final value = saved.value;
      _values[id]!.text = value == null
          ? ''
          : formatChecklistNumber(value, decimalComma: german);
      _reasons[id]!.text = saved.reason;
    }
    _note.text = draft.note;
    final updatedAt = draft.updatedAt;
    _draftNotice = l.checklistDraftLoaded(
      updatedAt == null ? '—' : formatDateTimeShort(context, updatedAt),
      draft.updatedBy.isEmpty ? '—' : draft.updatedBy,
    );
  }

  Map<int, ChecklistItemResult> _collect() {
    return {
      for (final item in _items)
        item.serverId!: ChecklistItemResult(
          status: _status[item.serverId!] ?? '',
          input: item.measurement ? _values[item.serverId!]!.text : null,
          reason: _reasons[item.serverId!]!.text,
        ),
    };
  }

  Future<void> _saveDraft() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _errors = const ChecklistErrorAssignment();
    });
    try {
      await widget.api.saveChecklistDraft(
        widget.checklist.id,
        results: _collect(),
        note: _note.text,
      );
      if (!mounted) return;
      _changedOnServer = true;
      setState(() {
        _busy = false;
        _dirty = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(l.checklistDraftSaved)));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
      _errors = const ChecklistErrorAssignment();
    });
    try {
      final result = await widget.api.completeChecklistRun(
        widget.checklist.id,
        results: _collect(),
        note: _note.text,
      );
      if (!mounted) return;
      _changedOnServer = true;
      setState(() {
        _busy = false;
        _dirty = false;
        _result = result;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  void _showError(ApiException error) {
    final l = AppLocalizations.of(context)!;
    final messages = error.errors.isNotEmpty ? error.errors : [error.message];
    setState(() {
      _busy = false;
      if (error.statusCode == 400) {
        _errors = assignChecklistErrors(_items, messages);
        _error = l.checklistValidationFailed;
      } else {
        _error = error.message;
      }
    });
  }

  Future<void> _confirmLeave() async {
    final l = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.checklistDiscardTitle),
        content: Text(l.checklistDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.checklistContinueEditing),
          ),
          TextButton(
            key: const Key('run-discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.checklistDiscardConfirm),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop(_changedOnServer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final title = widget.checklist.title.isNotEmpty
        ? widget.checklist.title
        : l.checklistFallback;
    return PopScope<bool>(
      canPop: !_dirty || _result != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: _result == null
              ? null
              : BackButton(onPressed: () => Navigator.of(context).pop(true)),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth(width),
            ),
            child: _result == null
                ? _form(context, l)
                : _RunResultView(
                    api: widget.api,
                    role: widget.role,
                    items: _items,
                    result: _result!,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, AppLocalizations l) {
    final c = WachbuchColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.checklist.description.isNotEmpty) ...[
          Text(
            widget.checklist.description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 12),
        ],
        if (_loadingDraft)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (_draftNotice != null) ...[
          _InfoLine(icon: Icons.history, text: _draftNotice!),
          const SizedBox(height: 8),
        ],
        if (_draftError != null) ...[
          ErrorBanner(message: l.checklistDraftLoadFailed(_draftError!)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loadingDraft ? null : _loadDraft,
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_error != null) ...[
          ErrorBanner(key: const Key('run-error'), message: _error!),
          for (final message in _errors.general) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: message),
          ],
          const SizedBox(height: 12),
        ],
        for (final item in _items) ...[
          _ItemCard(
            item: item,
            status: _status[item.serverId!] ?? '',
            value: _values[item.serverId!]!,
            reason: _reasons[item.serverId!]!,
            errors: _errors.byItem[item.serverId!] ?? const [],
            enabled: !_busy,
            onStatus: (status) => setState(() {
              _dirty = true;
              final id = item.serverId!;
              if (_status[id] == status) {
                _status.remove(id);
              } else {
                _status[id] = status;
              }
            }),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const Key('run-note'),
          controller: _note,
          enabled: !_busy,
          maxLength: 300,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: l.checklistNoteLabel),
        ),
        const FreeTextBoundaryHint(),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('run-finish'),
          onPressed: _busy || _loadingDraft ? null : _finish,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.task_alt),
          label: Text(l.checklistFinish),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('run-save-draft'),
          onPressed: _busy || _loadingDraft ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: Text(l.checklistSaveDraft),
        ),
        const SizedBox(height: 8),
        Text(
          l.checklistDraftShared,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grenzwerte als Text, z. B. „Grenzwerte 2 bis 8 °C“.
String checklistLimitsText(
  AppLocalizations l,
  ChecklistItem item, {
  required bool decimalComma,
}) {
  String fmt(double value) {
    final text = formatChecklistNumber(value, decimalComma: decimalComma);
    return item.unit.isEmpty ? text : '$text ${item.unit}';
  }

  final min = item.min;
  final max = item.max;
  if (min != null && max != null) {
    return l.checklistLimitsRange(fmt(min), fmt(max));
  }
  if (min != null) return l.checklistLimitsMin(fmt(min));
  if (max != null) return l.checklistLimitsMax(fmt(max));
  return '';
}

String checklistStatusLabel(AppLocalizations l, String status) {
  return switch (status) {
    ChecklistItemStatus.ok => l.checklistStatusOk,
    ChecklistItemStatus.notOk => l.checklistStatusNotOk,
    ChecklistItemStatus.na => l.checklistStatusNa,
    _ => l.checklistStatusOpen,
  };
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.status,
    required this.value,
    required this.reason,
    required this.errors,
    required this.enabled,
    required this.onStatus,
  });

  final ChecklistItem item;
  final String status;
  final TextEditingController value;
  final TextEditingController reason;
  final List<String> errors;
  final bool enabled;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final c = WachbuchColors.of(context);
    final id = item.serverId!;
    final german = Localizations.localeOf(context).languageCode == 'de';
    final limits = checklistLimitsText(l, item, decimalComma: german);
    final hasError = errors.isNotEmpty;
    return Card(
      key: Key('run-item-$id'),
      shape: hasError
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.label.isNotEmpty
                        ? item.label
                        : l.checklistItemFallback,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (item.required) ...[
                  const SizedBox(width: 8),
                  _RequiredBadge(label: l.checklistRequiredBadge),
                ],
              ],
            ),
            if (limits.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                limits,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in ChecklistItemStatus.values)
                  ChoiceChip(
                    key: Key('run-status-$id-$option'),
                    label: Text(checklistStatusLabel(l, option)),
                    selected: status == option,
                    onSelected: enabled ? (_) => onStatus(option) : null,
                  ),
              ],
            ),
            if (item.measurement && status != ChecklistItemStatus.na) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: value,
                builder: (context, current, _) {
                  final parsed = double.tryParse(
                    current.text.trim().replaceAll(',', '.'),
                  );
                  final outside = parsed != null && item.isOutOfLimits(parsed);
                  return TextField(
                    key: Key('run-value-$id'),
                    controller: value,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.checklistValueLabel,
                      suffixText: item.unit.isEmpty ? null : item.unit,
                      helperText: outside ? l.checklistValueOutOfLimits : null,
                      helperMaxLines: 3,
                      helperStyle: outside
                          ? TextStyle(
                              color: c.warning,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ],
            if (status == ChecklistItemStatus.notOk ||
                status == ChecklistItemStatus.na) ...[
              const SizedBox(height: 12),
              TextField(
                key: Key('run-reason-$id'),
                controller: reason,
                enabled: enabled,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: status == ChecklistItemStatus.na
                      ? l.checklistReasonRequiredLabel
                      : l.checklistFindingLabel,
                ),
              ),
            ],
            for (final message in errors) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Row(
                  key: Key('run-item-error-$id'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Ergebnis nach dem Abschluss: wie der Server den Lauf gespeichert hat,
/// dazu angelegte oder verknüpfte Mängel.
class _RunResultView extends StatelessWidget {
  const _RunResultView({
    required this.api,
    required this.role,
    required this.items,
    required this.result,
  });

  final WachbuchApi api;
  final String? role;
  final List<ChecklistItem> items;
  final ChecklistRunResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final german = Localizations.localeOf(context).languageCode == 'de';
    final defectIds = <int>[...result.defectsCreated, ...result.defectsLinked];
    return ListView(
      key: const Key('run-result'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Icon(Icons.task_alt, color: c.success, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.checklistRunDoneTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.checklistRunResultsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final item in items)
          if (result.results[item.serverId] case final saved?)
            _ResultRow(item: item, saved: saved, german: german),
        if (defectIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('run-open-defects'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DefectsScreen(
                  api: api,
                  role: role,
                  initialDefectId: defectIds.first,
                ),
              ),
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(l.checklistRunOpenDefects),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('run-done'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.checklistRunDone),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.saved,
    required this.german,
  });

  final ChecklistItem item;
  final ChecklistItemResult saved;
  final bool german;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final value = saved.value;
    final unit = saved.unit.isNotEmpty ? saved.unit : item.unit;
    final (icon, color) = switch (saved.status) {
      ChecklistItemStatus.ok => (Icons.check_circle_outline, c.success),
      ChecklistItemStatus.notOk => (Icons.cancel_outlined, scheme.error),
      ChecklistItemStatus.na => (Icons.remove_circle_outline, c.muted),
      _ => (Icons.radio_button_unchecked, c.muted),
    };
    final details = [
      checklistStatusLabel(l, saved.status),
      if (value != null)
        '${formatChecklistNumber(value, decimalComma: german)}'
            '${unit.isEmpty ? '' : ' $unit'}',
      if (saved.reason.isNotEmpty) saved.reason,
    ].join(' · ');
    final defectId = saved.defectId;
    return Padding(
      key: Key('run-result-${item.serverId}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved.text.isNotEmpty ? saved.text : item.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(details),
                if (defectId != null)
                  Text(
                    saved.defectLinked
                        ? l.checklistRunDefectLinked(defectId)
                        : l.checklistRunDefectCreated(defectId),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
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
