import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/screens/defect_create_sheet.dart';
import 'package:wachbuch_mobile/services/defect_photo.dart';
import 'package:wachbuch_mobile/state/defect_state.dart';
import 'package:wachbuch_mobile/state/station_roles.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/free_text_boundary_hint.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/priority_badge.dart';
import 'package:wachbuch_mobile/ui/status_chip.dart';

/// Persistent station defects: list, create, status workflow and photos.
class DefectsScreen extends StatefulWidget {
  const DefectsScreen({
    super.key,
    required this.api,
    this.role,
    this.initialDefectId,
    this.photoPicker,
  });

  final WachbuchApi api;

  /// Foto aus Kamera oder Mediathek; in Tests ersetzbar.
  final DefectPhotoPicker? photoPicker;

  /// Rolle aus `/me/`. Fehlt sie, lädt der Bildschirm `/me/` selbst; bis
  /// dahin bleiben „Bearbeiten“ und „erledigt“ ausgeblendet.
  final String? role;

  /// Öffnet nach dem ersten Laden diesen Mangel (z. B. aus einem
  /// Checklisten-Lauf), sofern er auf der ersten Seite steht.
  final int? initialDefectId;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  late final DefectState _state;
  String? _statusFilter;
  String? _role;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _state = DefectState(api: widget.api);
    _state.reload().then((_) => _openInitialDefect());
    if (_role == null) _loadRole();
  }

  void _openInitialDefect() {
    final id = widget.initialDefectId;
    if (id == null || !mounted) return;
    for (final defect in _state.items) {
      if (defect.id == id) {
        _openDetail(defect);
        return;
      }
    }
  }

  Future<void> _loadRole() async {
    try {
      final me = await widget.api.me();
      if (!mounted) return;
      setState(() => _role = (me['membership'] as Map?)?['role']?.toString());
    } catch (_) {
      // Ohne bekannte Rolle bleibt „erledigt“ ausgeblendet.
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  List<Defect> get _visible {
    final filter = _statusFilter;
    if (filter == null) return _state.items;
    return _state.items
        .where((item) => item.status == filter)
        .toList(growable: false);
  }

  /// „Mangel in drei Tipps“: mit [cameraFirst] startet direkt die Kamera.
  Future<void> _openCreate({bool cameraFirst = false}) async {
    final l = AppLocalizations.of(context)!;
    await reportDefect(
      context,
      api: widget.api,
      cameraFirst: cameraFirst,
      photoPicker: widget.photoPicker,
      create: (report) async {
        final created = await _state.create(
          title: report.title,
          description: report.description,
          assetRef: report.assetRef,
          priority: report.priority,
          category: report.category,
          dueAt: report.dueAt,
        );
        if (created == null) {
          throw ApiException(
            _state.lastError?.statusCode ?? 0,
            _state.error ?? l.defectCreateFailed,
          );
        }
        return created;
      },
    );
  }

  Future<void> _openDetail(Defect defect) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DefectDetailSheet(
        api: widget.api,
        defect: defect,
        onSetStatus: _state.setStatus,
        onEdit: (current, edit) => _state.update(
          current.id,
          description: edit.description,
          assetRef: edit.assetRef,
          priority: edit.priority,
          dueAt: edit.dueAt,
          clearDue: edit.clearDue,
        ),
        errorText: () => _state.error,
        canEdit: StationRoles.canEditDefect(_role),
        canClose: StationRoles.canCloseDefect(_role),
        photoPicker: widget.photoPicker ?? pickDefectPhoto,
      ),
    );
  }

  String _statusLabel(AppLocalizations l, String status) {
    return switch (status) {
      'in_progress' => l.handoverStatusInProgress,
      'waiting' => l.defectStatusWaiting,
      'done' => l.handoverStatusDone,
      _ => l.handoverStatusOpen,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.defectsTitle),
        actions: [
          IconButton(
            key: const Key('defects-add'),
            tooltip: l.defectAdd,
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('defects-report-photo'),
        onPressed: () => _openCreate(cameraFirst: true),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l.defectQuickWithPhoto),
      ),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final items = _visible;
          return RefreshIndicator(
            onRefresh: _state.reload,
            child: NotificationListener<ScrollEndNotification>(
              // Am Listenende automatisch die nächste Seite laden.
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 200 &&
                    _state.hasMore &&
                    !_state.loadingMore) {
                  _state.loadMore();
                }
                return false;
              },
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(
                        l.defectsHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in const [
                            'open',
                            'in_progress',
                            'waiting',
                            'done',
                          ])
                            FilterChip(
                              label: Text(_statusLabel(l, status)),
                              selected: _statusFilter == status,
                              onSelected: (selected) {
                                setState(() {
                                  _statusFilter = selected ? status : null;
                                });
                                // Erledigte lädt der Server nur auf Wunsch.
                                if (selected && status == 'done') {
                                  _state.setShowDone(true);
                                }
                              },
                            ),
                        ],
                      ),
                      SwitchListTile(
                        key: const Key('defects-show-done'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.defectsShowDone),
                        value: _state.showDone,
                        onChanged: _state.loading
                            ? null
                            : (value) {
                                if (!value && _statusFilter == 'done') {
                                  setState(() => _statusFilter = null);
                                }
                                _state.setShowDone(value);
                              },
                      ),
                      if (_state.hasData)
                        Text(
                          l.defectsShownOfTotal(
                            _state.items.length,
                            _state.totalCount,
                          ),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      const SizedBox(height: 12),
                      if (_state.error != null) ...[
                        ErrorBanner(message: _state.error!),
                        const SizedBox(height: 12),
                      ],
                      if (_state.loading && !_state.hasData)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l.defectsEmpty),
                        )
                      else
                        ...items.map(
                          (defect) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DefectCard(
                              defect: defect,
                              onTap: () => _openDetail(defect),
                            ),
                          ),
                        ),
                      if (_state.hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: OutlinedButton.icon(
                              key: const Key('defects-load-more'),
                              onPressed:
                                  _state.loadingMore ? null : _state.loadMore,
                              icon: _state.loadingMore
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_more),
                              label: Text(l.defectsLoadMore),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DefectDetailSheet extends StatefulWidget {
  const _DefectDetailSheet({
    required this.api,
    required this.defect,
    required this.onSetStatus,
    required this.onEdit,
    required this.errorText,
    this.canEdit = false,
    this.canClose = false,
    this.photoPicker = pickDefectPhoto,
  });

  final WachbuchApi api;
  final Defect defect;

  /// Foto aus Kamera oder Mediathek, mit Verkleinerung über 5 MiB.
  final DefectPhotoPicker photoPicker;
  final Future<bool> Function(int id, String status) onSetStatus;
  final Future<Defect?> Function(Defect current, _DefectEdit edit) onEdit;
  final String? Function() errorText;

  /// „Bearbeiten“ nur für Inhaltsrollen (Server: defect_detail PATCH).
  final bool canEdit;

  /// „Erledigt“ nur für WRITE_ROLES (Server: defect_status).
  final bool canClose;

  @override
  State<_DefectDetailSheet> createState() => _DefectDetailSheetState();
}

class _DefectDetailSheetState extends State<_DefectDetailSheet> {
  late Defect _defect;
  List<DefectAttachment> _attachments = const [];
  bool _attachmentsLoading = true;
  bool _photoBusy = false;
  String? _attachmentError;

  @override
  void initState() {
    super.initState();
    _defect = widget.defect;
    _reloadAttachments();
  }

  Future<void> _reloadAttachments() async {
    try {
      final attachments = await widget.api.defectAttachments(_defect.id);
      if (!mounted) return;
      setState(() {
        _attachments = attachments;
        _attachmentsLoading = false;
        _attachmentError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _attachmentsLoading = false;
        _attachmentError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attachmentsLoading = false;
        _attachmentError = error.toString();
      });
    }
  }

  Future<void> _edit() async {
    final l = AppLocalizations.of(context)!;
    final edit = await showModalBottomSheet<_DefectEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DefectEditSheet(defect: _defect),
    );
    if (edit == null || !mounted) return;
    final updated = await widget.onEdit(_defect, edit);
    if (!mounted) return;
    if (updated != null) {
      setState(() => _defect = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.defectUpdated)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.errorText() ?? l.defectUpdateFailed)),
      );
    }
  }

  Future<void> _setStatus(String status) async {
    final ok = await widget.onSetStatus(_defect.id, status);
    if (!mounted) return;
    if (ok) {
      setState(() => _defect = _defect.copyWith(status: status));
    }
  }

  Future<ImageSource?> _choosePhotoSource() {
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.defectTakePhoto),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.defectChoosePhoto),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto() async {
    final l = AppLocalizations.of(context)!;
    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;
    final PickedPhoto? photo;
    try {
      photo = await widget.photoPicker(source);
    } on PhotoPickException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (error.problem) {
            PhotoProblem.tooLarge => l.defectPhotoTooLarge,
            PhotoProblem.unsupportedType => l.defectQuickPhotoUnsupported,
            PhotoProblem.unavailable => l.defectQuickPhotoUnavailable,
          }),
        ),
      );
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await widget.api.uploadDefectAttachment(
        _defect.id,
        filename: photo.filename,
        contentType: photo.contentType,
        bytes: photo.bytes,
      );
      await _reloadAttachments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photo.downscaled
                ? '${l.defectPhotoUploaded} ${l.defectQuickPhotoDownscaled}'
                : l.defectPhotoUploaded,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _preview(DefectAttachment attachment) async {
    final l = AppLocalizations.of(context)!;
    try {
      final bytes = await widget.api.downloadAttachment(attachment.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nur Bilder rendern; PDFs u. Ä. bekommen einen Hinweis statt
                // eines kaputten Image-Widgets.
                Flexible(
                  child: attachment.contentType
                          .toLowerCase()
                          .startsWith('image/')
                      ? InteractiveViewer(
                          child: Image.memory(
                            bytes,
                            errorBuilder: (context, error, stackTrace) =>
                                _AttachmentPreviewUnavailable(
                              attachment: attachment,
                            ),
                          ),
                        )
                      : _AttachmentPreviewUnavailable(attachment: attachment),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(attachment.filename),
                ),
              ],
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.isEmpty ? l.detailsLoadFailed : error.message)),
      );
    }
  }

  String _statusLabel(AppLocalizations l, String status) => switch (status) {
        'in_progress' => l.handoverStatusInProgress,
        'waiting' => l.defectStatusWaiting,
        'done' => l.handoverStatusDone,
        _ => l.handoverStatusOpen,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _defect.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PriorityBadge(priority: _defect.priority),
                  StatusChip(status: _defect.status),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _defect.description.isEmpty
                    ? l.detailsNoFurtherInfo
                    : _defect.description,
              ),
              const SizedBox(height: 8),
              Text('${l.defectAssetLabel}: ${_defect.assetRef.isEmpty ? "—" : _defect.assetRef}'),
              Text('${l.defectOwnerLabel}: ${_defect.owner.isEmpty ? "—" : _defect.owner}'),
              if (_defect.dueDisplay.isNotEmpty)
                Text('${l.defectDueLabel}: ${_defect.dueDisplay}'),
              if (widget.canEdit) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('defect-edit'),
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.defectEdit),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(l.defectSetStatus, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in [
                    'open',
                    'in_progress',
                    'waiting',
                    if (widget.canClose || _defect.status == 'done') 'done',
                  ])
                    FilterChip(
                      key: Key('defect-status-$status'),
                      label: Text(_statusLabel(l, status)),
                      selected: _defect.status == status,
                      onSelected: _defect.status == status ? null : (_) => _setStatus(status),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.defectPhotosTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    // Das Theme macht FilledButtons volle Breite
                    // (Size.fromHeight); in einer Row wäre das unendlich.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, WachbuchTokens.touchTarget),
                    ),
                    onPressed: _photoBusy ? null : _addPhoto,
                    icon: _photoBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    label: Text(l.defectAddPhoto),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l.defectPhotosHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              if (_attachmentError != null) ErrorBanner(message: _attachmentError!),
              if (_attachmentsLoading)
                const Padding(
                  padding: EdgeInsets.all(WachbuchTokens.space5),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_attachments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.defectPhotosEmpty),
                )
              else
                for (final attachment in _attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: WachbuchTokens.touchTarget,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(attachment.filename),
                    subtitle: Text('${attachment.sizeLabel} · ${attachment.uploadedBy}'),
                    trailing: const Icon(Icons.open_in_full),
                    onTap: () => _preview(attachment),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefectCard extends StatelessWidget {
  const _DefectCard({required this.defect, required this.onTap});

  final Defect defect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: WachbuchTokens.touchTarget),
          child: Padding(
            padding: const EdgeInsets.all(WachbuchTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PriorityBadge(priority: defect.priority),
                    StatusChip(status: defect.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  defect.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (defect.assetRef.isNotEmpty) defect.assetRef,
                    if (defect.owner.isNotEmpty) defect.owner,
                    if (defect.dueDisplay.isNotEmpty)
                      '${l.defectDueLabel}: ${defect.dueDisplay}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefectEdit {
  const _DefectEdit({
    required this.description,
    required this.assetRef,
    required this.priority,
    this.dueAt,
    this.clearDue = false,
  });

  final String description;
  final String assetRef;
  final String priority;
  final DateTime? dueAt;
  final bool clearDue;
}

/// Mangel bearbeiten (PATCH /api/v1/defects/{id}/). Der Titel bleibt fest.
class _DefectEditSheet extends StatefulWidget {
  const _DefectEditSheet({required this.defect});

  final Defect defect;

  @override
  State<_DefectEditSheet> createState() => _DefectEditSheetState();
}

class _DefectEditSheetState extends State<_DefectEditSheet> {
  late final TextEditingController _description;
  late final TextEditingController _asset;
  late String _priority;
  DateTime? _dueAt;
  bool _dueCleared = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.defect.description);
    _asset = TextEditingController(text: widget.defect.assetRef);
    _priority = const ['normal', 'important', 'urgent'].contains(widget.defect.priority)
        ? widget.defect.priority
        : 'normal';
    _dueAt = widget.defect.dueAt;
  }

  @override
  void dispose() {
    _description.dispose();
    _asset.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dueCleared = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    final material = MaterialLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          WachbuchTokens.space5,
          0,
          WachbuchTokens.space5,
          WachbuchTokens.space5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.defect.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: WachbuchTokens.space2),
              const FreeTextBoundaryHint(),
              const SizedBox(height: WachbuchTokens.space4),
              TextField(
                key: const Key('defect-edit-description'),
                controller: _description,
                minLines: 3,
                maxLines: 6,
                maxLength: 3000,
                decoration: InputDecoration(
                  labelText: l.defectDescriptionLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              TextField(
                controller: _asset,
                maxLength: 160,
                decoration: InputDecoration(labelText: l.defectAssetLabel),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              DropdownButtonFormField<String>(
                key: const Key('defect-edit-priority'),
                initialValue: _priority,
                decoration: InputDecoration(labelText: l.defectPriorityLabel),
                items: [
                  for (final value in const ['normal', 'important', 'urgent'])
                    DropdownMenuItem(value: value, child: Text(defectPriorityLabel(l, value))),
                ],
                onChanged: (value) => setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDue,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _dueAt == null
                            ? l.defectDueLabel
                            : '${l.defectDueLabel}: ${material.formatMediumDate(_dueAt!)} · '
                                '${material.formatTimeOfDay(TimeOfDay.fromDateTime(_dueAt!), alwaysUse24HourFormat: true)}',
                        style: const TextStyle(
                          fontFeatures: WachbuchTokens.tabularFigures,
                        ),
                      ),
                    ),
                  ),
                  if (_dueAt != null) ...[
                    const SizedBox(width: WachbuchTokens.space2),
                    IconButton(
                      tooltip: l.defectDueClear,
                      onPressed: () => setState(() {
                        _dueAt = null;
                        _dueCleared = true;
                      }),
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: WachbuchTokens.space4),
              FilledButton.icon(
                key: const Key('defect-edit-save'),
                onPressed: () => Navigator.of(context).pop(_DefectEdit(
                  description: _description.text.trim(),
                  assetRef: _asset.text.trim(),
                  priority: _priority,
                  dueAt: _dueAt,
                  clearDue: _dueCleared,
                )),
                icon: const Icon(Icons.save_outlined),
                label: Text(l.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hinweis für Anhänge ohne Bildvorschau (z. B. PDF oder defekte Bilddaten).
class _AttachmentPreviewUnavailable extends StatelessWidget {
  const _AttachmentPreviewUnavailable({required this.attachment});

  final DefectAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final type = attachment.contentType.isEmpty ? '—' : attachment.contentType;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            l.attachmentPreviewUnavailable,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l.attachmentFileInfo(attachment.filename, type),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
