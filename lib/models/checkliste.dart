/// Checklisten der Wache (`GET /api/v1/checklisten/`).
///
/// Ab Server 0.28 liefert jede Checkliste zusätzlich `item_details` mit den
/// echten Kennungen der Prüfpunkte, Pflicht, Einheit und Grenzwerten. Nur mit
/// diesen Kennungen darf die App Ergebnisse je Prüfpunkt (`item_results`)
/// senden; Listenpositionen sind nie eine Kennung (Befund G2).
class Checklist {
  const Checklist({
    required this.id,
    required this.title,
    this.items = const [],
    this.completed = false,
    this.completedAt,
    this.completedBy = '',
    this.description = '',
    this.interval = '',
    this.dueNext,
    this.overdue = false,
    this.hasItemDetails = false,
    this.requiresPersonalLogin = false,
    this.lastCompletedPaperBackfill = false,
    this.draft,
  });

  /// Server (`GET /api/v1/checklisten/`) liefert `items` als Liste von
  /// Texten sowie `last_completed_at`/`last_completed_by`; ob die Liste im
  /// aktuellen Turnus erledigt ist, wird daraus und aus `interval` abgeleitet.
  /// Ab 0.28 kommen `item_details`, `requires_personal_login`,
  /// `last_completed_paper_backfill` und der gemeinsame Zwischenstand `draft`
  /// hinzu.
  factory Checklist.fromJson(Map<String, dynamic> json) {
    final dueNext = _readDate(json['due_next'] ?? json['dueNext']);
    final overdueFlag = json['overdue'] == true || json['is_overdue'] == true;
    final interval = _readInterval(json['interval']);
    final completedAt =
        _readDate(json['completed_at']) ??
        _readDate(json['last_completed_at']) ??
        _readDate(
          (json['completion'] is Map
              ? (json['completion'] as Map)['created_at']
              : null),
        );
    final overdue = overdueFlag || _isPastDue(dueNext);
    final details = json['item_details'];
    final hasDetails = details is List;
    final rawDraft = json['draft'];
    return Checklist(
      id: _readInt(json['id']),
      title: (json['title'] ?? json['name'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      items: hasDetails
          ? _readItemDetails(details)
          : _readItems(json['items'] ?? json['tasks'] ?? const []),
      completed:
          json['completed'] == true ||
          json['is_completed'] == true ||
          (!overdue && _completedInCurrentCycle(completedAt, interval)),
      completedAt: completedAt,
      completedBy: (json['last_completed_by'] ?? '').toString().trim(),
      interval: interval,
      dueNext: dueNext,
      overdue: overdue,
      hasItemDetails: hasDetails,
      requiresPersonalLogin: json['requires_personal_login'] == true,
      lastCompletedPaperBackfill: json['last_completed_paper_backfill'] == true,
      draft: rawDraft is Map
          ? ChecklistDraft.fromJson(Map<String, dynamic>.from(rawDraft))
          : null,
    );
  }

  final int id;
  final String title;
  final String description;
  final List<ChecklistItem> items;
  final bool completed;
  final DateTime? completedAt;

  /// Anzeigename der Person, die zuletzt abgeschlossen hat (falls bekannt).
  final String completedBy;

  /// `daily` | `weekly` | `monthly` | empty when not recurring.
  final String interval;
  final DateTime? dueNext;
  final bool overdue;

  /// Server ab 0.28: `item_details` war in der Antwort enthalten.
  final bool hasItemDetails;

  /// Nachweis-Checkliste: Das Wachenterminal darf sie nicht abschließen. Die
  /// App ist nie eine Terminal-Sitzung; sie zeigt eine 403 des Servers an.
  final bool requiresPersonalLogin;

  /// Der letzte Lauf ist ein Nachtrag vom Papierbogen.
  final bool lastCompletedPaperBackfill;

  /// Gemeinsamer Zwischenstand der Wache aus der Liste (nur online, nie im
  /// Offline-Cache). Fortgesetzt wird über `/zwischenstand/`.
  final ChecklistDraft? draft;

  int get checkedCount => items.where((item) => item.checked).length;

  bool get allChecked =>
      items.isNotEmpty && items.every((item) => item.checked);

  bool get isRecurring => interval.isNotEmpty;

  /// Ergebnisse je Prüfpunkt sind möglich: Der Server kennt `item_details`
  /// und jeder Prüfpunkt trägt seine Server-Kennung.
  bool get supportsItemResults =>
      hasItemDetails &&
      items.isNotEmpty &&
      items.every((item) => item.serverId != null);

  int get requiredCount => items.where((item) => item.required).length;

  bool get isDueToday {
    if (completed) return false;
    if (overdue) return true;
    final due = dueNext;
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  Checklist copyWith({
    int? id,
    String? title,
    String? description,
    List<ChecklistItem>? items,
    bool? completed,
    DateTime? completedAt,
    String? completedBy,
    String? interval,
    DateTime? dueNext,
    bool? overdue,
    bool? hasItemDetails,
    bool? requiresPersonalLogin,
    bool? lastCompletedPaperBackfill,
    ChecklistDraft? draft,
    bool clearDraft = false,
  }) {
    return Checklist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      items: items ?? this.items,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      interval: interval ?? this.interval,
      dueNext: dueNext ?? this.dueNext,
      overdue: overdue ?? this.overdue,
      hasItemDetails: hasItemDetails ?? this.hasItemDetails,
      requiresPersonalLogin:
          requiresPersonalLogin ?? this.requiresPersonalLogin,
      lastCompletedPaperBackfill:
          lastCompletedPaperBackfill ?? this.lastCompletedPaperBackfill,
      draft: clearDraft ? null : (draft ?? this.draft),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Checklist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Prüfpunkt einer Checkliste.
///
/// [serverId] ist die Kennung aus `item_details` (Server ab 0.28) und der
/// einzige zulässige Schlüssel für `item_results`. Bei älteren Servern, die
/// nur Texte liefern, bleibt sie `null`; [id] ist dann nur eine Anzeige-
/// Nummer und wird nie an den Server geschickt.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.label,
    this.checked = false,
    this.note = '',
    this.serverId,
    this.position = 0,
    this.required = false,
    this.unit = '',
    this.min,
    this.max,
    this.measurement = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: _readInt(json['id']),
      label: (json['label'] ?? json['title'] ?? json['text'] ?? '')
          .toString()
          .trim(),
      checked: json['checked'] == true || json['done'] == true,
      note: (json['note'] ?? '').toString().trim(),
    );
  }

  /// Ein Eintrag aus `item_details`: `id`, `text`, `position`, `required`,
  /// `unit`, `min`, `max` (Dezimalzahl als Text, 0 ist ein echter
  /// Grenzwert) und `measurement`.
  factory ChecklistItem.fromDetailJson(Map<String, dynamic> json) {
    final id = _readStrictInt(json['id']);
    final min = _readDecimal(json['min']);
    final max = _readDecimal(json['max']);
    final unit = (json['unit'] ?? '').toString().trim();
    return ChecklistItem(
      id: id ?? 0,
      serverId: id,
      label: (json['text'] ?? '').toString().trim(),
      position: _readInt(json['position']),
      required: json['required'] == true,
      unit: unit,
      min: min,
      max: max,
      measurement:
          json['measurement'] == true ||
          unit.isNotEmpty ||
          min != null ||
          max != null,
    );
  }

  final int id;
  final String label;
  final bool checked;
  final String note;

  /// Kennung des Prüfpunkts auf dem Server (Schlüssel für `item_results`).
  final int? serverId;
  final int position;
  final bool required;
  final String unit;
  final double? min;
  final double? max;

  /// Messpunkt: bei „in Ordnung“/„nicht in Ordnung“ ist ein Messwert Pflicht.
  final bool measurement;

  bool get hasLimits => min != null || max != null;

  /// Liegt [value] außerhalb der Grenzwerte? Der Server wertet beim
  /// Abschluss selbst aus; die App zeigt nur einen Hinweis.
  bool isOutOfLimits(double value) {
    final low = min;
    final high = max;
    return (low != null && value < low) || (high != null && value > high);
  }
}

/// Status eines Prüfpunkts im Lauf (`item_results[<id>].status`).
abstract final class ChecklistItemStatus {
  static const ok = 'ok';
  static const notOk = 'not_ok';
  static const na = 'na';
  static const values = [ok, notOk, na];

  static String normalize(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return values.contains(value) ? value : '';
  }
}

/// Eingabe bzw. gespeichertes Ergebnis eines Prüfpunkts.
class ChecklistItemResult {
  const ChecklistItemResult({
    this.status = '',
    this.value,
    this.input,
    this.reason = '',
    this.text = '',
    this.unit = '',
    this.defectId,
    this.defectLinked = false,
  });

  /// Gespeichertes Ergebnis aus Zwischenstand oder Lauf: `status`, `value`
  /// (Zahl oder `null`), `reason` sowie die Kopie des Prüfpunkts (`text`,
  /// `unit`) und beim Lauf `defect_id`/`defect_linked`.
  factory ChecklistItemResult.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    return ChecklistItemResult(
      status: ChecklistItemStatus.normalize(json['status']),
      value: rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(rawValue?.toString().replaceAll(',', '.') ?? ''),
      reason: (json['reason'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      defectId: _readStrictInt(json['defect_id']),
      defectLinked: json['defect_linked'] == true,
    );
  }

  final String status;

  /// Gespeicherter Messwert (Zahl) aus Zwischenstand oder Lauf.
  final double? value;

  /// Messwert, wie er eingegeben wurde (z. B. „5,2“); geht unverändert an
  /// den Server, der Dezimalkomma, Bereich und Grenzwerte selbst prüft.
  final String? input;
  final String reason;
  final String text;
  final String unit;
  final int? defectId;
  final bool defectLinked;

  /// Messwert für den Server: Eingabe, sonst der gespeicherte Wert, sonst
  /// `null` (leer).
  String? get valueText {
    final typed = input?.trim();
    if (typed != null && typed.isNotEmpty) return typed;
    final stored = value;
    return stored == null ? null : formatChecklistNumber(stored);
  }
}

/// Zahl ohne überflüssige Nachkommastellen („9.5“, „10“, „-18“), wie der
/// Server sie in Begründungen schreibt. [decimalComma] für deutsche Anzeige.
String formatChecklistNumber(double value, {bool decimalComma = false}) {
  var text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return decimalComma ? text.replaceAll('.', ',') : text;
}

/// Gemeinsamer Zwischenstand der Wache (`draft`).
///
/// Enthält Begründungen, Notiz und den Namen der zuletzt bearbeitenden
/// Person. Er wird nur online geladen und nie in den Offline-Cache
/// geschrieben (CLIENT-OFFLINE-CONTRACT §2).
class ChecklistDraft {
  const ChecklistDraft({
    required this.id,
    this.note = '',
    this.results = const {},
    this.updatedAt,
    this.updatedBy = '',
  });

  factory ChecklistDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['item_results'];
    final results = <int, ChecklistItemResult>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key == null || value is! Map) continue;
        results[key] = ChecklistItemResult.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    }
    return ChecklistDraft(
      id: _readInt(json['id']),
      note: (json['note'] ?? '').toString(),
      results: Map.unmodifiable(results),
      updatedAt: _readDate(json['updated_at']),
      updatedBy: (json['updated_by'] ?? '').toString().trim(),
    );
  }

  final int id;
  final String note;

  /// Ergebnisse je Server-Kennung des Prüfpunkts.
  final Map<int, ChecklistItemResult> results;
  final DateTime? updatedAt;
  final String updatedBy;
}

/// Antwort auf einen abgeschlossenen Lauf (`201` von `/abschluss/`).
class ChecklistRunResult {
  const ChecklistRunResult({
    required this.id,
    required this.checklistId,
    this.results = const {},
    this.defectsCreated = const [],
    this.defectsLinked = const [],
    this.completedBy = '',
    this.createdAt,
    this.interval = '',
    this.dueNext,
    this.overdue = false,
  });

  factory ChecklistRunResult.fromJson(Map<String, dynamic> json) {
    final raw = json['item_results'];
    final results = <int, ChecklistItemResult>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key == null || value is! Map) continue;
        results[key] = ChecklistItemResult.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    }
    final by = json['completed_by'];
    return ChecklistRunResult(
      id: _readInt(json['id']),
      checklistId: _readInt(json['checklist']),
      results: Map.unmodifiable(results),
      defectsCreated: _readIntList(json['defects_created']),
      defectsLinked: _readIntList(json['defects_linked']),
      completedBy: (by is Map ? by['display_name'] : by)?.toString() ?? '',
      createdAt: _readDate(json['created_at']),
      interval: _readInterval(json['interval']),
      dueNext: _readDate(json['due_next']),
      overdue: json['overdue'] == true,
    );
  }

  final int id;
  final int checklistId;

  /// Ergebnisse, wie der Server sie gespeichert hat (z. B. ein Messwert
  /// außerhalb der Grenzwerte als „nicht in Ordnung“ mit Begründung).
  final Map<int, ChecklistItemResult> results;
  final List<int> defectsCreated;
  final List<int> defectsLinked;
  final String completedBy;
  final DateTime? createdAt;
  final String interval;
  final DateTime? dueNext;
  final bool overdue;
}

List<ChecklistItem> _readItems(Object? value) {
  if (value is! List) return const [];
  final items = <ChecklistItem>[];
  for (final (index, item) in value.indexed) {
    if (item is Map) {
      items.add(ChecklistItem.fromJson(Map<String, dynamic>.from(item)));
    } else if (item is String && item.trim().isNotEmpty) {
      // Ältere Server liefern Prüfpunkte als reine Texte. Die Nummer dient nur
      // der Anzeige und ist keine Server-Kennung ([ChecklistItem.serverId]).
      items.add(ChecklistItem(id: index + 1, label: item.trim()));
    }
  }
  return List.unmodifiable(items);
}

List<ChecklistItem> _readItemDetails(List<dynamic> value) {
  final items = [
    for (final entry in value)
      if (entry is Map)
        ChecklistItem.fromDetailJson(Map<String, dynamic>.from(entry)),
  ];
  items.sort((a, b) {
    final byPosition = a.position.compareTo(b.position);
    return byPosition != 0
        ? byPosition
        : (a.serverId ?? 0).compareTo(b.serverId ?? 0);
  });
  return List.unmodifiable(items);
}

/// Erledigt, wenn der letzte Abschluss in den laufenden Turnus fällt
/// (ohne Turnus: heute).
bool _completedInCurrentCycle(DateTime? completedAt, String interval) {
  if (completedAt == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final done = DateTime(completedAt.year, completedAt.month, completedAt.day);
  return switch (interval) {
    'weekly' => today.difference(done).inDays < 7,
    'monthly' => done.year == today.year && done.month == today.month,
    _ => done == today,
  };
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

bool _isPastDue(DateTime? due) {
  if (due == null) return false;
  final today = DateTime.now();
  final dueDay = DateTime(due.year, due.month, due.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return dueDay.isBefore(todayDay);
}

String _readInterval(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return switch (raw) {
    'daily' || 'weekly' || 'monthly' => raw,
    _ => '',
  };
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Nur echte positive Kennungen; alles andere ist `null`.
int? _readStrictInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _readDecimal(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

List<int> _readIntList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable([
    for (final entry in value)
      if (_readStrictInt(entry) != null) _readStrictInt(entry)!,
  ]);
}
