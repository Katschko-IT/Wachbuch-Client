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
    this.createdAt,
  });

  /// Arten, die App 1.1 kennt (`UserNotification.Kind` des Servers 0.24 bis
  /// 0.26). Nur diese erscheinen als Benachrichtigung und werden als gelesen
  /// gemeldet. Neue Arten späterer Server (z. B. technische Hinweise für
  /// Admins) bleiben unberührt: kein Text auf dem Sperrbildschirm, dessen
  /// Inhalt die App nicht kennt, und kein `read_at`, das eine Eskalation auf
  /// dem Server beenden könnte.
  static const shownKinds = {'vehicle_ready', 'coffee_due'};

  factory CrewNotice.fromJson(Map<String, dynamic> json) {
    return CrewNotice(
      id: _readInt(json['id']),
      kind: (json['kind'] ?? '').toString().trim(),
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      read: json['read'] == true,
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
  final DateTime? createdAt;

  /// Fail closed: fehlende oder unbekannte Art wird nicht angezeigt.
  bool get isShownKind => shownKinds.contains(kind);
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
