import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/state/handover_state.dart';
import 'package:wachbuch_mobile/ui/free_text_boundary_hint.dart';
import 'package:wachbuch_mobile/ui/handover_filter.dart';

/// Formular „Neue Übergabe“ (POST /api/v1/handovers/).
///
/// Felder und Grenzen wie auf dem Server: Titel bis 160 Zeichen, Text bis
/// 3000 Zeichen, Bereich und Dringlichkeit aus den Server-Werten.
class HandoverCreateSheet extends StatefulWidget {
  const HandoverCreateSheet({super.key, required this.state});

  final HandoverState state;

  static const categories = ['station', 'vehicle', 'material', 'task', 'safety'];
  static const priorities = ['normal', 'important', 'urgent'];

  @override
  State<HandoverCreateSheet> createState() => _HandoverCreateSheetState();
}

class _HandoverCreateSheetState extends State<HandoverCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  String _category = 'station';
  String _priority = 'normal';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.create(
        title: _title.text.trim(),
        details: _details.text.trim(),
        category: _category,
        priority: _priority,
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
        _error = l.handoverCreateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.handoverCreateHeading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const FreeTextBoundaryHint(),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('handover-create-title'),
                controller: _title,
                maxLength: 160,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.handoverFieldTitle),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l.handoverTitleRequired
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('handover-create-details'),
                controller: _details,
                maxLength: 3000,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l.handoverFieldDetails,
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l.handoverDetailsRequired
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('handover-create-category'),
                initialValue: _category,
                decoration: InputDecoration(labelText: l.handoverFieldCategory),
                items: [
                  for (final value in HandoverCreateSheet.categories)
                    DropdownMenuItem(
                      value: value,
                      child: Text(handoverCategoryLabel(value, l)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 16),
              Text(
                l.handoverFieldPriority,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('handover-create-priority'),
                segments: [
                  for (final value in HandoverCreateSheet.priorities)
                    ButtonSegment(
                      value: value,
                      label: Text(handoverPriorityLabel(value, l)),
                    ),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) =>
                    setState(() => _priority = selection.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              // Kein automatisches Wiederholen: der Hinweis erklärt, warum.
              Text(
                l.handoverNoAutoRetryHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('handover-create-submit'),
                onPressed: _saving ? null : () => _submit(l),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l.handoverSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
