import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/qr_scan_screen.dart';
import 'package:wachbuch_mobile/services/defect_photo.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/free_text_boundary_hint.dart';

/// Kategorien eines Mangels (`Defect.Category` des Servers).
const defectCategories = [
  'material',
  'vehicle',
  'device',
  'key',
  'safety',
  'facility',
  'task',
];

const defectPriorities = ['normal', 'important', 'urgent'];

String defectCategoryLabel(AppLocalizations l, String category) {
  return switch (category) {
    'vehicle' => l.defectCategoryVehicle,
    'material' => l.defectCategoryMaterial,
    'safety' => l.defectCategorySafety,
    'facility' => l.defectCategoryFacility,
    'key' => l.defectCategoryKey,
    'device' => l.defectCategoryDevice,
    'task' => l.defectCategoryTask,
    _ => l.handoverEnumUnknown,
  };
}

String defectPriorityLabel(AppLocalizations l, String priority) {
  return switch (priority) {
    'urgent' => l.handoverPriorityUrgent,
    'important' => l.handoverPriorityImportant,
    _ => l.handoverPriorityNormal,
  };
}

/// Kategorie passend zum Bezug, wie das Mangelformular im Web: Fahrzeug,
/// Gerät oder Schlüssel; ohne Bezug „Material“.
String defaultCategoryFor(StationAsset? asset) {
  return switch (asset?.kind) {
    'vehicle' => 'vehicle',
    'device' => 'device',
    'key' => 'key',
    _ => 'material',
  };
}

/// Kennung (`asset_id`) aus einem QR-Code eines Fahrzeugs oder Geräts
/// dieses Servers: Fuhrpark (`/fuhrpark/v/<kennung>/`), Medizinproduktebuch
/// (`/mpg/d/<kennung>/`) oder Mangelformular (`/maengel/neu/?asset=…`).
/// QR-Codes anderer Server werden nicht übernommen.
String? assetIdFromQr(String raw, String baseUrl) {
  final uri = Uri.tryParse(raw.trim());
  final base = Uri.tryParse(baseUrl);
  if (uri == null || base == null || !uri.hasScheme) return null;
  if (uri.scheme != base.scheme ||
      uri.host.toLowerCase() != base.host.toLowerCase() ||
      uri.port != base.port) {
    return null;
  }
  final path = uri.path;
  final match = RegExp(
    r'^/(?:fuhrpark/v|mpg/d)/([A-Za-z0-9_-]+)/?$',
  ).firstMatch(path);
  if (match != null) return match.group(1);
  if (path == '/maengel/neu/' || path == '/maengel/neu') {
    final asset =
        (uri.queryParameters['asset'] ?? uri.queryParameters['asset_ref'] ?? '')
            .trim();
    return asset.isEmpty ? null : asset;
  }
  return null;
}

/// Ein neuer Mangel aus „Mangel in drei Tipps“.
class DefectReport {
  const DefectReport({
    required this.title,
    this.description = '',
    this.assetRef = '',
    this.priority = 'normal',
    this.category = 'material',
    this.dueAt,
    this.photo,
  });

  /// Titel; leer gelassen bildet die App ihn wie das Web-Formular aus
  /// Kategorie und Bezug (die API verlangt einen Titel).
  final String title;
  final String description;
  final String assetRef;
  final String priority;
  final String category;
  final DateTime? dueAt;
  final PickedPhoto? photo;
}

/// Ergebnis von [submitDefectReport].
class DefectReportOutcome {
  const DefectReportOutcome({this.defect, this.error, this.photoError});

  final Defect? defect;

  /// Mangel wurde nicht angelegt.
  final String? error;

  /// Mangel angelegt, Foto aber nicht hochgeladen.
  final String? photoError;

  bool get created => defect != null;
}

/// Legt den Mangel an und lädt danach das Foto hoch. Beide Aufrufe werden
/// nicht automatisch wiederholt. Scheitert nur das Foto, bleibt der Mangel
/// bestehen; das Foto lässt sich im Mangel erneut hinzufügen.
Future<DefectReportOutcome> submitDefectReport(
  WachbuchApi api,
  DefectReport report, {
  Future<Defect> Function(DefectReport report)? create,
}) async {
  final Defect defect;
  try {
    defect = create != null
        ? await create(report)
        : await api.createDefect(
            title: report.title,
            description: report.description,
            assetRef: report.assetRef,
            priority: report.priority,
            category: report.category,
            dueAt: report.dueAt,
          );
  } on ApiException catch (error) {
    return DefectReportOutcome(error: error.message);
  } catch (error) {
    return DefectReportOutcome(error: error.toString());
  }
  final photo = report.photo;
  if (photo == null) return DefectReportOutcome(defect: defect);
  try {
    await api.uploadDefectAttachment(
      defect.id,
      filename: photo.filename,
      contentType: photo.contentType,
      bytes: photo.bytes,
    );
    return DefectReportOutcome(defect: defect);
  } on ApiException catch (error) {
    return DefectReportOutcome(defect: defect, photoError: error.message);
  } catch (error) {
    return DefectReportOutcome(defect: defect, photoError: error.toString());
  }
}

/// Öffnet „Mangel melden“. Mit [cameraFirst] startet sofort die Kamera
/// (Mangel mit Foto in drei Tipps: melden, auslösen, speichern); mit
/// [preselected] ist der Bezug schon gewählt (Geräte & Fahrzeuge, QR-Code).
Future<DefectReport?> showDefectReportSheet(
  BuildContext context, {
  required WachbuchApi api,
  StationAsset? preselected,
  bool cameraFirst = false,
  DefectPhotoPicker? photoPicker,
  Future<String?> Function(BuildContext context)? qrReader,
}) {
  return showModalBottomSheet<DefectReport>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DefectReportSheet(
      api: api,
      preselected: preselected,
      cameraFirst: cameraFirst,
      photoPicker: photoPicker ?? pickDefectPhoto,
      qrReader: qrReader,
    ),
  );
}

/// Meldet einen neuen Mangel mit [showDefectReportSheet] und
/// [submitDefectReport] und zeigt das Ergebnis als Snackbar.
Future<Defect?> reportDefect(
  BuildContext context, {
  required WachbuchApi api,
  StationAsset? preselected,
  bool cameraFirst = false,
  Future<Defect> Function(DefectReport report)? create,
  DefectPhotoPicker? photoPicker,
}) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final report = await showDefectReportSheet(
    context,
    api: api,
    preselected: preselected,
    cameraFirst: cameraFirst,
    photoPicker: photoPicker,
  );
  if (report == null) return null;
  final outcome = await submitDefectReport(api, report, create: create);
  final message =
      outcome.error ??
      (outcome.photoError != null
          ? l.defectCreatedPhotoFailed(outcome.photoError!)
          : report.photo != null
          ? l.defectCreatedWithPhoto
          : l.defectCreated);
  messenger.showSnackBar(SnackBar(content: Text(message)));
  return outcome.defect;
}

class DefectReportSheet extends StatefulWidget {
  const DefectReportSheet({
    super.key,
    required this.api,
    required this.photoPicker,
    this.preselected,
    this.cameraFirst = false,
    this.qrReader,
  });

  final WachbuchApi api;
  final DefectPhotoPicker photoPicker;
  final StationAsset? preselected;
  final bool cameraFirst;

  /// QR-Code lesen; Standard ist die Kamera mit Hinweis und Berechtigung.
  final Future<String?> Function(BuildContext context)? qrReader;

  @override
  State<DefectReportSheet> createState() => _DefectReportSheetState();
}

const _noReference = '';
const _customReference = '__custom__';

class _DefectReportSheetState extends State<DefectReportSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _customText = TextEditingController();

  List<StationAsset> _assets = const [];
  String _reference = _noReference;
  String _priority = 'normal';
  String _category = 'material';
  bool _categoryTouched = false;
  DateTime? _dueAt;
  PickedPhoto? _photo;
  bool _pickingPhoto = false;
  String? _error;
  String? _photoNotice;

  ServerInfo _server = const ServerInfo();
  DefectPage? _duplicates;
  int _duplicateGeneration = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final preselected = widget.preselected;
    if (preselected != null) {
      _assets = [preselected];
      _reference = preselected.id;
      _category = defaultCategoryFor(preselected);
    }
    _customText.addListener(_onCustomTextChanged);
    _loadAssets();
    _loadServerInfo();
    if (widget.cameraFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickPhoto(ImageSource.camera);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _description.dispose();
    _customText.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await widget.api.assets();
      if (!mounted) return;
      setState(() {
        final preselected = widget.preselected;
        _assets = [
          ...assets,
          if (preselected != null && !assets.any((a) => a.id == preselected.id))
            preselected,
        ];
      });
    } catch (_) {
      // Ohne „Geräte & Fahrzeuge“ bleibt der Bezug als Freitext möglich.
    }
  }

  Future<void> _loadServerInfo() async {
    final info = await widget.api.serverInfo();
    if (!mounted) return;
    setState(() => _server = info);
    _checkDuplicates();
  }

  StationAsset? get _selectedAsset {
    for (final asset in _assets) {
      if (asset.id == _reference) return asset;
    }
    return null;
  }

  String get _referenceText {
    if (_reference == _customReference) return _customText.text.trim();
    return _selectedAsset?.label ?? '';
  }

  /// Wert für `?asset=`: die `asset_id` oder der Freitext.
  String get _referenceQuery {
    if (_reference == _customReference) return _customText.text.trim();
    return _selectedAsset?.id ?? '';
  }

  void _onCustomTextChanged() {
    if (_reference != _customReference) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _checkDuplicates);
    setState(() {});
  }

  void _selectReference(String value) {
    setState(() {
      _reference = value;
      _duplicates = null;
      if (!_categoryTouched) _category = defaultCategoryFor(_selectedAsset);
    });
    _checkDuplicates();
  }

  Future<void> _checkDuplicates() async {
    final generation = ++_duplicateGeneration;
    final query = _referenceQuery;
    if (query.isEmpty || !_server.supportsDefectReferenceFilter) {
      if (_duplicates != null) setState(() => _duplicates = null);
      return;
    }
    try {
      final page = await widget.api.defectsForReference(query);
      if (!mounted || generation != _duplicateGeneration) return;
      setState(() => _duplicates = page);
    } catch (_) {
      // Der Hinweis ist eine Hilfe; ohne Antwort wird einfach gemeldet.
      if (!mounted || generation != _duplicateGeneration) return;
      setState(() => _duplicates = null);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _pickingPhoto = true;
      _photoNotice = null;
    });
    try {
      final photo = await widget.photoPicker(source);
      if (!mounted) return;
      setState(() {
        if (photo != null) {
          _photo = photo;
          _photoNotice = photo.downscaled ? l.defectQuickPhotoDownscaled : null;
          _error = null;
        }
      });
    } on PhotoPickException catch (error) {
      if (!mounted) return;
      setState(() {
        _photoNotice = switch (error.problem) {
          PhotoProblem.unsupportedType => l.defectQuickPhotoUnsupported,
          PhotoProblem.tooLarge => l.defectPhotoTooLarge,
          PhotoProblem.unavailable => l.defectQuickPhotoUnavailable,
        };
      });
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _scanQr() async {
    final l = AppLocalizations.of(context)!;
    final base = widget.api.baseUrl;
    final reader =
        widget.qrReader ??
        (BuildContext context) => openQrScanner(
          context,
          accept: (raw) => assetIdFromQr(raw, base) != null,
          purpose: l.defectQrCameraMessage,
          title: l.defectQrScanTitle,
          invalidMessage: l.defectQrScanInvalid,
          footer: '',
          deniedMessage: l.defectQrCameraDenied,
        );
    final raw = await reader(context);
    if (raw == null || !mounted) return;
    final id = assetIdFromQr(raw, base)?.toLowerCase();
    StationAsset? match;
    for (final asset in _assets) {
      if (asset.id.toLowerCase() == id) match = asset;
    }
    if (match == null) {
      setState(() => _error = l.defectReferenceQrNoMatch);
      return;
    }
    setState(() => _error = null);
    _selectReference(match.id);
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDate: _dueAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _autoTitle(AppLocalizations l) {
    final category = defectCategoryLabel(l, _category);
    final reference = _referenceText;
    final title = reference.isEmpty
        ? l.defectAutoTitleNoReference(category)
        : l.defectAutoTitle(category, reference);
    return title.length > 160 ? title.substring(0, 160) : title;
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final description = _description.text.trim();
    final reference = _referenceText;
    if (title.isEmpty &&
        reference.isEmpty &&
        description.isEmpty &&
        _photo == null) {
      setState(() => _error = l.defectNeedsContent);
      return;
    }
    Navigator.of(context).pop(
      DefectReport(
        title: title.isNotEmpty ? title : _autoTitle(l),
        description: description,
        assetRef: reference,
        priority: _priority,
        category: _category,
        dueAt: _dueAt,
        photo: _photo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
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
                l.defectQuickTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              _photoSection(context, l),
              const SizedBox(height: WachbuchTokens.space4),
              _referenceSection(context, l),
              if (_duplicates case final page? when page.count > 0) ...[
                const SizedBox(height: WachbuchTokens.space3),
                _DuplicateHint(page: page),
              ],
              const SizedBox(height: WachbuchTokens.space4),
              _ChipGroup(
                title: l.defectCategoryLabel,
                keyPrefix: 'defect-category',
                values: defectCategories,
                selected: _category,
                label: (value) => defectCategoryLabel(l, value),
                onSelected: (value) => setState(() {
                  _category = value;
                  _categoryTouched = true;
                }),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              _ChipGroup(
                title: l.defectPriorityLabel,
                keyPrefix: 'defect-priority',
                values: defectPriorities,
                selected: _priority,
                label: (value) => defectPriorityLabel(l, value),
                onSelected: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: WachbuchTokens.space4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _customText,
                builder: (context, _, _) => TextField(
                  key: const Key('defect-title'),
                  controller: _title,
                  maxLength: 160,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.defectTitleOptionalLabel,
                    helperText: l.defectTitleAutoHint(_autoTitle(l)),
                    helperMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(height: WachbuchTokens.space3),
              TextField(
                key: const Key('defect-description'),
                controller: _description,
                minLines: 2,
                maxLines: 6,
                maxLength: 3000,
                decoration: InputDecoration(
                  labelText: l.defectDescriptionLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const FreeTextBoundaryHint(),
              const SizedBox(height: WachbuchTokens.space3),
              OutlinedButton.icon(
                onPressed: _pickDue,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dueAt == null
                      ? l.defectDueLabel
                      : '${l.defectDueLabel}: ${MaterialLocalizations.of(context).formatMediumDate(_dueAt!)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_dueAt!), alwaysUse24HourFormat: true)}',
                  style: const TextStyle(
                    fontFeatures: WachbuchTokens.tabularFigures,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: WachbuchTokens.space3),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: WachbuchTokens.space4),
              FilledButton.icon(
                key: const Key('defect-submit'),
                onPressed: _pickingPhoto ? null : _submit,
                icon: const Icon(Icons.save_outlined),
                label: Text(l.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSection(BuildContext context, AppLocalizations l) {
    final c = WachbuchColors.of(context);
    final photo = _photo;
    final children = <Widget>[];
    if (photo != null) {
      children.add(
        Row(
          key: const Key('defect-photo-preview'),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WachbuchTokens.radiusSm),
              child: Image.memory(
                photo.bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(Icons.image_outlined),
                ),
              ),
            ),
            const SizedBox(width: WachbuchTokens.space3),
            Expanded(child: Text(l.defectQuickPhotoReady(photo.sizeLabel))),
            IconButton(
              tooltip: l.defectQuickPhotoRemove,
              onPressed: () => setState(() {
                _photo = null;
                _photoNotice = null;
              }),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
    } else {
      children.addAll([
        FilledButton.tonalIcon(
          key: const Key('defect-photo-camera'),
          onPressed: _pickingPhoto
              ? null
              : () => _pickPhoto(ImageSource.camera),
          icon: _pickingPhoto
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
          label: Text(l.defectQuickPhotoCamera),
        ),
        const SizedBox(height: WachbuchTokens.space2),
        TextButton.icon(
          key: const Key('defect-photo-gallery'),
          onPressed: _pickingPhoto
              ? null
              : () => _pickPhoto(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l.defectQuickPhotoGallery),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (_photoNotice != null) ...[
          const SizedBox(height: WachbuchTokens.space2),
          Text(
            _photoNotice!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ],
        const SizedBox(height: WachbuchTokens.space1),
        Text(
          l.defectPhotosHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ],
    );
  }

  Widget _referenceSection(BuildContext context, AppLocalizations l) {
    final groups = <String, List<StationAsset>>{
      'vehicle': [],
      'device': [],
      'key': [],
    };
    for (final asset in _assets) {
      groups.putIfAbsent(asset.kind, () => []).add(asset);
    }
    String groupLabel(String kind) => switch (kind) {
      'vehicle' => l.defectReferenceGroupVehicles,
      'key' => l.defectReferenceGroupKeys,
      _ => l.defectReferenceGroupDevices,
    };
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: _noReference, child: Text(l.defectReferenceNone)),
      for (final entry in groups.entries)
        if (entry.value.isNotEmpty) ...[
          DropdownMenuItem<String>(
            enabled: false,
            value: '__group_${entry.key}',
            child: Text(
              groupLabel(entry.key),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final asset in entry.value)
            DropdownMenuItem(
              value: asset.id,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(asset.label, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      DropdownMenuItem(
        value: _customReference,
        child: Text(l.defectReferenceOther),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('defect-reference'),
                initialValue: _reference,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.defectAssetLabel),
                items: items,
                onChanged: (value) => _selectReference(value ?? _noReference),
              ),
            ),
            const SizedBox(width: WachbuchTokens.space2),
            IconButton(
              key: const Key('defect-reference-qr'),
              tooltip: l.defectReferenceScanQr,
              onPressed: _scanQr,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ],
        ),
        if (_reference == _customReference) ...[
          const SizedBox(height: WachbuchTokens.space3),
          TextField(
            key: const Key('defect-reference-text'),
            controller: _customText,
            maxLength: 160,
            decoration: InputDecoration(labelText: l.defectReferenceText),
          ),
        ],
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final String keyPrefix;
  final List<String> values;
  final String selected;
  final String Function(String value) label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: WachbuchTokens.space2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  key: Key('$keyPrefix-$value'),
                  label: Text(label(value)),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateHint extends StatelessWidget {
  const _DuplicateHint({required this.page});

  final DefectPage page;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = WachbuchColors.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const Key('defect-duplicates'),
        padding: const EdgeInsets.all(WachbuchTokens.space3),
        decoration: BoxDecoration(
          color: c.warningSoft,
          border: Border.all(color: c.warningAccent),
          borderRadius: BorderRadius.circular(WachbuchTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: c.warning),
                const SizedBox(width: WachbuchTokens.space2),
                Expanded(
                  child: Text(
                    l.defectDuplicateTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WachbuchTokens.space1),
            Text(
              l.defectDuplicateCount(page.count),
              style: TextStyle(color: c.text),
            ),
            for (final defect in page.items.take(3))
              Padding(
                padding: const EdgeInsets.only(top: WachbuchTokens.space1),
                child: Text(
                  '• ${defect.title}',
                  style: TextStyle(color: c.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
