/// Eigene Lesepflicht einer Dienstanweisung
/// (`GET /api/v1/dienstanweisungen/`, Server ab 0.28).
///
/// Die Antwort nennt nur den eigenen Stand: keine anderen Personen und
/// keine Quote. Der Text selbst liegt auf der Webseite ([url]).
class ReadingObligation {
  const ReadingObligation({
    required this.id,
    required this.title,
    this.docNumber = '',
    this.revisionId,
    this.revisionVersion = '',
    this.ackDueDate,
    this.overdue = false,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.inTargetGroup = true,
    this.url = '',
  });

  factory ReadingObligation.fromJson(Map<String, dynamic> json) {
    final revision = json['revision'];
    return ReadingObligation(
      id: _readInt(json['id']),
      docNumber: (json['doc_number'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      revisionId: revision is Map ? _readPositive(revision['id']) : null,
      revisionVersion: revision is Map
          ? (revision['version'] ?? '').toString().trim()
          : '',
      ackDueDate: _readDay(json['ack_due_date']),
      overdue: json['overdue'] == true,
      acknowledged: json['acknowledged'] == true,
      acknowledgedAt: DateTime.tryParse(
        (json['acknowledged_at'] ?? '').toString(),
      )?.toLocal(),
      inTargetGroup: json['in_target_group'] != false,
      url: (json['url'] ?? '').toString().trim(),
    );
  }

  final int id;
  final String docNumber;
  final String title;

  /// Aktuelle Version; wird beim Bestätigen mitgeschickt (`revision`), damit
  /// der Server bei einer inzwischen neueren Version mit 409 ablehnt.
  final int? revisionId;
  final String revisionVersion;
  final DateTime? ackDueDate;

  /// Vom Server berechnet: Frist abgelaufen und noch nicht bestätigt.
  final bool overdue;
  final bool acknowledged;
  final DateTime? acknowledgedAt;
  final bool inTargetGroup;

  /// Webseite der Dienstanweisung (Pfad auf dem Server).
  final String url;

  bool get isOpen => !acknowledged;
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readPositive(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

/// `ack_due_date` ist ein Kalendertag (`2026-11-20`).
DateTime? _readDay(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
