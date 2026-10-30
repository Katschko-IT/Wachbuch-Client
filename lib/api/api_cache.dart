import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wachbuch_mobile/security/secure_storage.dart';

/// Small encrypted cache for read-only API snapshots.
///
/// It is intentionally session-scoped: the storage namespace includes a SHA-256
/// digest of server origin + app token so cached station data can never bleed
/// into another login on the same device.
abstract class ApiCache {
  Future<Map<String, dynamic>?> readJson(String key);
  Future<void> writeJson(String key, Map<String, dynamic> value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Regeln für den Offline-Lesecache nach `docs/CLIENT-OFFLINE-CONTRACT.md`
/// im Server-Repository (§2, §3, §5, §6).
///
/// - Positivliste: eigene Mitgliedschaft (`/me/`), Checklisten und die
///   Übergabeliste ohne Freitext. Kaffeekasse, Übergabe-Details, Mängel und
///   Anhänge werden nie gespeichert. Tagesaufgaben kennt der Client nicht.
/// - Jeder Eintrag trägt `fetched_at`/`expires_at` und gilt höchstens 24 h.
/// - Kein Cache für die Rollen `admin`, `cashier` und `auditor`.
class OfflineCachePolicy {
  OfflineCachePolicy._();

  static const schemaVersion = 1;
  static const maxAge = Duration(hours: 24);

  /// Grobe Obergrenze je Eintrag (Vertrag: höchstens 5 MB je Origin).
  static const maxEntryBytes = 5 * 1024 * 1024;

  /// Toleranz für leicht vorgehende Geräteuhren.
  static const _clockSkew = Duration(minutes: 5);

  static const excludedRoles = {'admin', 'cashier', 'auditor'};
  static const cacheableKeys = {'me', 'checklists', 'handovers'};

  static bool isCacheable(String key) => cacheableKeys.contains(key);

  static bool roleAllowed(String? role) =>
      role != null && role.isNotEmpty && !excludedRoles.contains(role);

  /// Rolle aus einer `/me/`-Antwort (`membership.role`).
  static String? roleOf(Map<String, dynamic>? me) {
    final membership = me?['membership'];
    if (membership is! Map) return null;
    final role = membership['role']?.toString().trim();
    return role == null || role.isEmpty ? null : role;
  }

  static Map<String, dynamic> wrap(Map<String, dynamic> data, DateTime now) {
    final fetchedAt = now.toUtc();
    return {
      'schema_version': schemaVersion,
      'fetched_at': fetchedAt.toIso8601String(),
      'expires_at': fetchedAt.add(maxAge).toIso8601String(),
      'data': data,
    };
  }

  /// Nutzdaten eines gültigen, höchstens 24 h alten Eintrags, sonst `null`.
  static Map<String, dynamic>? unwrap(
    Map<String, dynamic>? entry,
    DateTime now, {
    bool ignoreAge = false,
  }) {
    if (entry == null || entry['schema_version'] != schemaVersion) return null;
    final data = entry['data'];
    final fetchedAt = DateTime.tryParse(entry['fetched_at']?.toString() ?? '');
    if (data is! Map || fetchedAt == null) return null;
    if (!ignoreAge) {
      final age = now.toUtc().difference(fetchedAt.toUtc());
      if (age > maxAge || age < -_clockSkew) return null;
    }
    return Map<String, dynamic>.from(data);
  }

  /// Reduziert eine Serverantwort auf die laut Vertrag erlaubten Felder.
  static Map<String, dynamic> minimize(String key, Map<String, dynamic> body) {
    switch (key) {
      case 'me':
        final user = _map(body['user']);
        final membership = _map(body['membership']);
        final station = _map(membership['station']);
        return {
          'user': _pick(user, const ['id', 'username', 'first_name', 'last_name']),
          'membership': {
            ..._pick(membership, const ['role', 'role_label']),
            'station': _pick(station, const ['id', 'name', 'slug', 'modules']),
          },
        };
      case 'handovers':
        return {
          'results': [
            for (final item in _list(body['results']))
              {
                'id': item['id'],
                'title': item['title'],
                if (item['created_at'] != null) 'created_at': item['created_at'],
                if (item['updated_at'] != null) 'updated_at': item['updated_at'],
                'urgent': item['urgent'] == true || item['priority'] == 'urgent',
              },
          ],
        };
      case 'checklists':
        return {
          'results': [
            for (final item in _list(body['results']))
              {
                ..._pick(item, const [
                  'id',
                  'title',
                  'description',
                  'last_completed_at',
                  'last_completed_by',
                ]),
                'items': [
                  for (final entry in (item['items'] is List ? item['items'] as List : const []))
                    if (entry is Map)
                      (entry['label'] ?? entry['title'] ?? entry['text'] ?? '').toString()
                    else
                      entry.toString(),
                ],
              },
          ],
        };
    }
    return const {};
  }

  /// Bringt gespeicherte Daten wieder in die Form, die der Client liest.
  static Map<String, dynamic> restore(String key, Map<String, dynamic> data) {
    if (key != 'handovers') return data;
    return {
      'results': [
        for (final item in _list(data['results']))
          {
            'id': item['id'],
            'title': item['title'],
            if (item['created_at'] != null) 'created_at': item['created_at'],
            if (item['updated_at'] != null) 'updated_at': item['updated_at'],
            if (item['urgent'] == true) 'priority': 'urgent',
          },
      ],
    };
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  static Map<String, dynamic> _pick(Map<String, dynamic> source, List<String> keys) => {
        for (final key in keys)
          if (source.containsKey(key)) key: source[key],
      };
}

class SecureApiCache implements ApiCache {
  SecureApiCache({
    required this.namespace,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? createWachbuchSecureStorage();

  factory SecureApiCache.forSession({
    required String baseUrl,
    required String token,
    FlutterSecureStorage? storage,
  }) {
    final digest = sha256.convert(utf8.encode('$baseUrl|$token')).toString();
    return SecureApiCache(
      namespace: digest.substring(0, 24),
      storage: storage,
    );
  }

  final String namespace;
  final FlutterSecureStorage _storage;
  final Set<String> _knownKeys = <String>{};

  String get _prefix => 'wachbuch_cache_${namespace}_';
  String _key(String key) => '$_prefix$key';

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await _storage.read(key: _key(key));
    if (raw == null || raw.isEmpty) return null;
    _knownKeys.add(key);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      await _storage.delete(key: _key(key));
      _knownKeys.remove(key);
    }
    return null;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    _knownKeys.add(key);
    await _storage.write(key: _key(key), value: jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    _knownKeys.remove(key);
    await _storage.delete(key: _key(key));
  }

  @override
  Future<void> clear() async {
    // Enumerate secure storage instead of relying only on this process' memory.
    // Snapshot the matching keys before deleting: the secure-storage mock (and
    // some platform implementations) can mutate the backing map on delete.
    final all = await _storage.readAll();
    final persistedKeys = all.keys
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    for (final storageKey in persistedKeys) {
      await _storage.delete(key: storageKey);
    }
    _knownKeys.clear();
  }
}
