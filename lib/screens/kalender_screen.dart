import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/empty_state.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/free_text_boundary_hint.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key, required this.api, this.canCreate = false});

  final WachbuchApi api;

  /// Termine anlegen dürfen Schichtleitung und Admin (Server: WRITE_ROLES).
  final bool canCreate;

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  List<KalenderEntry> _entries = const [];
  bool _loading = true;
  String? _error;
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
      final entries = await widget.api.kalender();
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _entries = entries;
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

  Future<void> _openCreate() async {
    final l = AppLocalizations.of(context)!;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => KalenderCreateSheet(api: widget.api),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kalenderCreated)));
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.kalenderTitle)),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              key: const Key('kalender-create'),
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.kalenderCreate),
            )
          : null,
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
    if (_loading && _entries.isEmpty) {
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
          if (_entries.isEmpty && _error == null)
            EmptyState(
              icon: Icons.event_busy,
              title: AppLocalizations.of(context)!.kalenderEmptyTitle,
              message: AppLocalizations.of(context)!.kalenderEmpty,
              actionLabel: AppLocalizations.of(context)!.refreshTooltip,
              onAction: _reload,
            )
          else
            for (final entry in _entries) ...[
              _KalenderCard(entry: entry),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _KalenderCard extends StatelessWidget {
  const _KalenderCard({required this.entry});

  final KalenderEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = WachbuchColors.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WachbuchTokens.radiusLg),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WachbuchTokens.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: WachbuchTokens.inputHeight,
              decoration: BoxDecoration(
                color: c.brand,
                borderRadius: BorderRadius.circular(WachbuchTokens.radiusSm),
              ),
            ),
            const SizedBox(width: WachbuchTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isNotEmpty
                        ? entry.title
                        : AppLocalizations.of(context)!.kalenderEntryFallback,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: c.text,
                        ),
                  ),
                  const SizedBox(height: WachbuchTokens.space1),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: c.muted,
                      ),
                      const SizedBox(width: WachbuchTokens.space1),
                      Expanded(
                        child: Text(
                          _formatRange(entry, AppLocalizations.of(context)!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: c.muted,
                                fontFeatures: WachbuchTokens.tabularFigures,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.location.isNotEmpty) ...[
                    const SizedBox(height: WachbuchTokens.space1),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: c.muted,
                        ),
                        const SizedBox(width: WachbuchTokens.space1),
                        Expanded(
                          child: Text(
                            entry.location,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: c.muted,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entry.description.isNotEmpty) ...[
                    const SizedBox(height: WachbuchTokens.space2),
                    Text(
                      entry.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.text,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRange(KalenderEntry entry, AppLocalizations l10n) {
  final start = entry.startsAt;
  final end = entry.endsAt;
  if (start == null && end == null) return l10n.kalenderTimeTbd;
  if (entry.allDay) {
    return start != null ? _formatDay(start) : l10n.kalenderAllDay;
  }
  if (start != null && end != null) {
    final sameDay = _isSameDay(start, end);
    return sameDay
        ? '${_formatDay(start)}, ${_formatTime(start)} – ${_formatTime(end)} Uhr'
        : '${_formatDay(start)} ${_formatTime(start)} – ${_formatDay(end)} ${_formatTime(end)} Uhr';
  }
  if (start != null) return '${_formatDay(start)}, ${_formatTime(start)} Uhr';
  return _formatDay(end!);
}

String _formatDay(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

String _formatTime(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Termin anlegen: Titel, Beschreibung, Beginn und Ende (Standard: 1 Stunde).
class KalenderCreateSheet extends StatefulWidget {
  const KalenderCreateSheet({super.key, required this.api, this.now});

  final WachbuchApi api;

  /// Für Tests: fester „Jetzt“-Zeitpunkt.
  final DateTime? now;

  @override
  State<KalenderCreateSheet> createState() => _KalenderCreateSheetState();
}

class _KalenderCreateSheetState extends State<KalenderCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
    _end = _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 3),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pick(_start);
    if (picked == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = picked;
      _end = picked.add(duration.isNegative ? const Duration(hours: 1) : duration);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(_end);
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_end.isBefore(_start)) {
      setState(() => _error = l.kalenderEndBeforeStart);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createKalenderEntry(
        title: _title.text.trim(),
        description: _description.text.trim(),
        startsAt: _start,
        endsAt: _end,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.kalenderCreateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final material = MaterialLocalizations.of(context);
    String format(DateTime value) =>
        '${material.formatMediumDate(value)}, ${material.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          WachbuchTokens.space5,
          0,
          WachbuchTokens.space5,
          WachbuchTokens.space5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.kalenderCreate,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: WachbuchTokens.space2),
              const FreeTextBoundaryHint(),
              const SizedBox(height: WachbuchTokens.space4),
              TextFormField(
                key: const Key('kalender-create-title'),
                controller: _title,
                maxLength: 160,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.kalenderFieldTitle),
                validator: (value) => (value ?? '').trim().isEmpty ? l.kalenderTitleRequired : null,
              ),
              const SizedBox(height: WachbuchTokens.space2),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l.kalenderFieldDescription,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              ListTile(
                key: const Key('kalender-create-start'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: WachbuchTokens.touchTarget,
                leading: Icon(Icons.play_arrow_outlined, color: c.brand),
                title: Text(l.kalenderFieldStart),
                subtitle: Text(
                  format(_start),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.muted,
                        fontFeatures: WachbuchTokens.tabularFigures,
                      ),
                ),
                onTap: _pickStart,
              ),
              ListTile(
                key: const Key('kalender-create-end'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: WachbuchTokens.touchTarget,
                leading: Icon(Icons.stop_outlined, color: c.brand),
                title: Text(l.kalenderFieldEnd),
                subtitle: Text(
                  format(_end),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.muted,
                        fontFeatures: WachbuchTokens.tabularFigures,
                      ),
                ),
                onTap: _pickEnd,
              ),
              if (_error != null) ...[
                const SizedBox(height: WachbuchTokens.space2),
                Text(_error!, style: TextStyle(color: c.danger)),
              ],
              const SizedBox(height: WachbuchTokens.space4),
              FilledButton.icon(
                key: const Key('kalender-create-submit'),
                onPressed: _saving ? null : () => _submit(l),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(l.kalenderSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
