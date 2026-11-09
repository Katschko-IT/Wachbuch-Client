/// Laufende Desinfektionssperre eines Fahrzeugs, das die Person besetzt.
///
/// Quelle: `GET /api/v1/fahrzeuge/sperren/` (Server ab 0.24.0). Die App plant
/// daraus eine lokale Erinnerung zu [lockedUntil]. Das Fahrzeug wird vom
/// Server nie automatisch freigegeben; die Besatzung setzt den Status selbst.
class VehicleLock {
  const VehicleLock({
    required this.vehicleId,
    required this.callSign,
    required this.lockedUntil,
    required this.key,
    required this.title,
    required this.body,
  });

  factory VehicleLock.fromJson(Map<String, dynamic> json) {
    return VehicleLock(
      vehicleId: _readInt(json['vehicle_id']),
      callSign: (json['call_sign'] ?? '').toString(),
      lockedUntil:
          DateTime.tryParse((json['locked_until'] ?? '').toString())?.toUtc(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }

  final int vehicleId;
  final String callSign;
  final DateTime? lockedUntil;

  /// Ereignisschlüssel; identisch mit [CrewNotice.key] derselben Sperre.
  final String key;
  final String title;
  final String body;
}

/// Eintrag im persönlichen Posteingang (`GET /api/v1/benachrichtigungen/`).
class CrewNotice {
  const CrewNotice({
    required this.id,
    required this.key,
    required this.title,
    required this.body,
    required this.read,
    this.kind = '',
    this.url = '',
    this.createdAt,
  });

  static const vehicleReady = 'vehicle_ready';
  static const coffeeDue = 'coffee_due';
  static const systemHealth = 'system_health';
  static const mpgTrainingMissing = 'mpg_training_missing';
  static const deadlineDue = 'deadline_due';
  static const sopDue = 'sop_due';

  /// Arten, die App 1.2 kennt (`UserNotification.Kind` des Servers 0.28):
  /// Fahrzeugfreigabe, Kaffeekasse, technische Hinweise (nur Master-Admins),
  /// fehlende MPG-Einweisung, Fristen-Erinnerungen samt Wochenübersicht und
  /// Lesefristen von Dienstanweisungen. Die App fragt mit `?kinds=` genau
  /// diese ab; nur sie erscheinen als Benachrichtigung und werden einzeln als
  /// gelesen gemeldet. Arten späterer Server bleiben unberührt: kein Text auf
  /// dem Sperrbildschirm, dessen Inhalt die App nicht kennt, und kein
  /// `read_at`, das eine Eskalation auf dem Server beenden könnte.
  static const shownKinds = {
    vehicleReady,
    coffeeDue,
    systemHealth,
    mpgTrainingMissing,
    deadlineDue,
    sopDue,
  };

  /// Arten, deren Text eine Person nennen kann (z. B. wer ohne gültige
  /// Einweisung eine Funktionskontrolle gemacht hat). Als Benachrichtigung
  /// auf dem Gerät – also womöglich auf dem Sperrbildschirm – erscheint dafür
  /// nur ein neutraler Text; den vollen Text zeigt der Posteingang
  /// „Hinweise“ in der App.
  static const personalDetailKinds = {mpgTrainingMissing};

  /// Wert für `?kinds=` (kommagetrennt, feste Reihenfolge).
  static String get kindsQuery => shownKinds.join(',');

  factory CrewNotice.fromJson(Map<String, dynamic> json) {
    return CrewNotice(
      id: _readInt(json['id']),
      kind: (json['kind'] ?? '').toString().trim(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      read: json['read'] == true,
      url: (json['url'] ?? '').toString().trim(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  final int id;

  /// `kind` des Servers, z. B. `vehicle_ready`; leer bei fehlender Angabe.
  final String kind;
  final String key;
  final String title;
  final String body;
  final bool read;

  /// Webseite zum Hinweis (Pfad auf dem Server, z. B. die Dienstanweisung).
  final String url;
  final DateTime? createdAt;

  /// Fail closed: fehlende oder unbekannte Art wird nicht angezeigt.
  bool get isShownKind => shownKinds.contains(kind);

  /// Text kann eine Person nennen: auf dem Gerät nur neutral anzeigen.
  bool get mayNamePerson => personalDetailKinds.contains(kind);

  /// Wochenübersicht der Fristen (Art `deadline_due`, eigener Schlüssel).
  bool get isWeeklyDigest =>
      kind == deadlineDue && key.startsWith('deadline_weekly_digest:');
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
