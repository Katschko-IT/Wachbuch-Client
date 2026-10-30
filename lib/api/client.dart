/// HTTP client for Wachwerk `/api/v1/` (Paperless/Nextcloud-style token auth).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/crew_notice.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/models/pinboard_note.dart';
import 'package:wachbuch_mobile/models/report_stats.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

typedef WachbuchApiFactory = WachbuchApi Function(String baseUrl);

/// Wird aufgerufen, wenn der Server die Sitzung nicht mehr anerkennt
/// (401 oder 403 „Kein aktiver Wachenzugang“). Die App meldet dann ab.
typedef UnauthorizedCallback = void Function(ApiException error);

WachbuchApi defaultWachbuchApiFactory(String baseUrl) {
  return WachbuchApi(baseUrl: baseUrl);
}

/// Retries transient network failures (timeouts, connection errors and 5xx)
/// with exponential backoff. Contract errors are never retried.
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  Duration delay = initialDelay;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } on TimeoutException {
      if (attempt == maxAttempts) rethrow;
    } on http.ClientException {
      if (attempt == maxAttempts) rethrow;
    } on ApiException catch (error) {
      final isConnectionError = error.statusCode == 0;
      final isServerError = error.statusCode >= 500 && error.statusCode != 501;
      if (!isConnectionError && !isServerError) rethrow;
      if (attempt == maxAttempts) rethrow;
    }
    await Future.delayed(delay);
    delay *= 2;
  }
  throw StateError('Unreachable retry state');
}

class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.message, {
    this.code,
    this.correlationId,
  });

  final int statusCode;
  final String message;
  final String? code;
  final String? correlationId;

  /// 403 aus `api_token_required`: Konto ohne aktive Mitgliedschaft.
  /// Der Server liefert dafür nur den allgemeinen Code `forbidden`, daher wird
  /// zusätzlich der Meldungstext geprüft.
  bool get isNoActiveMembership =>
      statusCode == 403 &&
      (code == 'no_active_membership' ||
          message.toLowerCase().contains('kein aktiver wachenzugang'));

  /// Sitzung ist serverseitig nicht (mehr) gültig.
  bool get isSessionInvalid => statusCode == 401 || isNoActiveMembership;

  bool get isMfaRequired =>
      statusCode == 403 &&
      (code == 'mfa_required' ||
          code == 'mfa_setup_required' ||
          message.toUpperCase().contains('MFA'));

  @override
  String toString() {
    final correlation = correlationId == null || correlationId!.isEmpty
        ? ''
        : ' [$correlationId]';
    return 'ApiException($statusCode${code == null ? '' : ', $code'}): $message$correlation';
  }
}

class AuthToken {
  const AuthToken({required this.value, this.expiresAt});

  final String value;
  final DateTime? expiresAt;
}

class WachbuchApi {
  WachbuchApi({
    required this.baseUrl,
    this.token,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
    ApiCache? cache,
    this.onUnauthorized,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _cache = cache,
        _clock = clock ?? DateTime.now;

  /// Origin only, e.g. https://wache.example.org (no trailing slash).
  final String baseUrl;
  final String? token;
  final Duration requestTimeout;
  final http.Client _client;
  final ApiCache? _cache;

  /// App-weite Abmeldung bei ungültiger Sitzung (nur für Anfragen mit Token).
  final UnauthorizedCallback? onUnauthorized;
  final DateTime Function() _clock;

  /// Rolle aus der letzten erfolgreichen `/me/`-Antwort dieser Sitzung.
  String? _role;

  /// Der Offline-Cache darf nur gelesen werden, nachdem diese Sitzung online
  /// bestätigt wurde (CLIENT-OFFLINE-CONTRACT §3.5/§5).
  bool _sessionConfirmed = false;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        0,
        'Zeitlimit überschritten. Bitte Server und Verbindung prüfen.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(0, 'Netzwerkfehler: ${error.message}');
    }
  }

  /// Meldet eine ungültige Sitzung an [onUnauthorized] und wirft den Fehler.
  Never _raise(ApiException error) {
    final hasToken = token != null && token!.isNotEmpty;
    if (hasToken && error.isSessionInvalid) {
      onUnauthorized?.call(error);
    }
    throw error;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          throw const FormatException('JSON object expected');
        }
      } on FormatException {
        if (response.statusCode >= 500) {
          throw ApiException(
            response.statusCode,
            'Serverfehler (${response.statusCode}). Bitte später erneut versuchen.',
          );
        }
        final proxyMessage = _proxyErrorMessage(response);
        if (proxyMessage != null) {
          _raise(ApiException(response.statusCode, proxyMessage));
        }
        _raise(ApiException(
          response.statusCode,
          'Der Server hat eine ungültige Antwort gesendet.',
        ));
      }
    }
    if (response.statusCode >= 400) {
      final error = body['error'];
      String? message;
      String? code;
      String? correlationId;
      if (error is Map) {
        final mapped = Map<String, dynamic>.from(error);
        message = mapped['message']?.toString();
        code = mapped['code']?.toString();
        correlationId = mapped['correlation_id']?.toString();
      } else if (error is String) {
        // Backwards compatibility with server <= 0.14.x.
        message = error;
      }
      message ??= body['message']?.toString();
      code ??= body['code']?.toString();
      correlationId ??= body['correlation_id']?.toString();
      final resolved = message?.isNotEmpty == true
          ? message! + _retryAfterHint(response)
          : _proxyErrorMessage(response) ??
              'Anfrage fehlgeschlagen (${response.statusCode})';
      _raise(ApiException(
        response.statusCode,
        resolved,
        code: code,
        correlationId: correlationId,
      ));
    }
    return body;
  }

  /// Verständliche Meldungen für Antworten ohne JSON-Körper, wie sie z. B.
  /// nginx vor dem Server bei zu großen Uploads oder Ratenbegrenzung liefert.
  String? _proxyErrorMessage(http.Response response) {
    return switch (response.statusCode) {
      413 => 'Datei zu groß (max. 2 MiB)',
      415 => 'Dateityp nicht unterstützt',
      429 => 'Zu viele Anfragen – bitte kurz warten${_retryAfterHint(response)}',
      _ => null,
    };
  }

  /// Wartezeit aus `Retry-After` (nur Sekundenangabe) für 429-Meldungen.
  String _retryAfterHint(http.Response response) {
    if (response.statusCode != 429) return '';
    final raw = response.headers['retry-after']?.trim();
    final seconds = raw == null ? null : int.tryParse(raw);
    if (seconds == null || seconds <= 0) return '';
    return ' (erneut versuchen in $seconds s)';
  }

  /// Rolle aus dem gespeicherten `/me/`-Snapshot (optional ohne Altersprüfung).
  Future<String?> _storedRole({bool ignoreAge = false}) async {
    final raw = await _cache?.readJson('me');
    final data = OfflineCachePolicy.unwrap(raw, _clock(), ignoreAge: ignoreAge);
    return OfflineCachePolicy.roleOf(data);
  }

  Future<String?> _effectiveRole() async => _role ?? await _storedRole();

  /// Übernimmt die Rolle aus `/me/`. Ausgeschlossene Rollen und ein
  /// Rollenwechsel löschen den Cache vollständig (Vertrag §2, §8).
  Future<void> _applyRole(Map<String, dynamic> me) async {
    final role = OfflineCachePolicy.roleOf(me);
    final cache = _cache;
    try {
      final previous = _role ?? await _storedRole(ignoreAge: true);
      // Snapshots älterer App-Versionen tragen kein schema_version und können
      // verbotene Daten (z. B. Kaffeekasse) enthalten: komplett verwerfen.
      final storedMe = _role == null ? await cache?.readJson('me') : null;
      final legacy = storedMe != null &&
          storedMe['schema_version'] != OfflineCachePolicy.schemaVersion;
      if (cache != null &&
          (legacy ||
              !OfflineCachePolicy.roleAllowed(role) ||
              (previous != null && previous != role))) {
        await cache.clear();
      }
    } catch (_) {
      // Cache-Fehler dürfen eine erfolgreiche Anfrage nicht scheitern lassen.
    } finally {
      _role = role;
    }
  }

  Future<void> _cacheWrite(String key, Map<String, dynamic> body) async {
    final cache = _cache;
    if (cache == null || !OfflineCachePolicy.isCacheable(key)) return;
    try {
      if (!OfflineCachePolicy.roleAllowed(await _effectiveRole())) return;
      final entry = OfflineCachePolicy.wrap(
        OfflineCachePolicy.minimize(key, body),
        _clock(),
      );
      if (jsonEncode(entry).length > OfflineCachePolicy.maxEntryBytes) return;
      await cache.writeJson(key, entry);
    } catch (_) {
      // Cache failure must never turn a successful online request into an error.
    }
  }

  Future<Map<String, dynamic>?> _cacheRead(String key) async {
    final cache = _cache;
    if (cache == null ||
        !_sessionConfirmed ||
        !OfflineCachePolicy.isCacheable(key)) {
      return null;
    }
    try {
      if (!OfflineCachePolicy.roleAllowed(await _effectiveRole())) return null;
      final raw = await cache.readJson(key);
      final data = OfflineCachePolicy.unwrap(raw, _clock());
      if (data == null) {
        // Abgelaufene oder alte Einträge ohne Zeitstempel verwerfen.
        if (raw != null) await cache.remove(key);
        return null;
      }
      return OfflineCachePolicy.restore(key, data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    String? cacheKey,
    String? moduleLabel,
    Future<void> Function(Map<String, dynamic> body)? onOnline,
  }) async {
    try {
      final body = await _withRetry(() async {
        final response = await _send(
          _client.get(_uri(path), headers: _headers()),
        );
        final checked = moduleLabel == null
            ? response
            : _requireModule(response, moduleLabel);
        return _decode(checked);
      });
      if (token != null && token!.isNotEmpty) _sessionConfirmed = true;
      if (onOnline != null) await onOnline(body);
      if (cacheKey != null) await _cacheWrite(cacheKey, body);
      return body;
    } on ApiException catch (error) {
      if (error.statusCode == 0 && cacheKey != null) {
        final cached = await _cacheRead(cacheKey);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  /// GET /api/v1/ – discovery without auth.
  Future<Map<String, dynamic>> discover() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/'), headers: _headers(auth: false)),
      );
      final body = _decode(response);
      ensureWachbuchDiscovery(body);
      return body;
    });
  }

  /// POST /api/v1/token/
  Future<AuthToken> obtainToken({
    required String username,
    required String password,
    String label = 'Mobile App',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/token/'),
          headers: _headers(auth: false),
          body: jsonEncode({
            'username': username,
            'password': password,
            'label': label,
          }),
        ),
      );
      final body = _decode(response);
      final value = body['token'] as String?;
      if (value == null || value.isEmpty) {
        throw ApiException(response.statusCode, 'Kein Token in der Antwort.');
      }
      return AuthToken(
        value: value,
        expiresAt: _parseExpiresAt(body['expires_at']),
      );
    }, maxAttempts: 1);
  }

  /// POST /api/v1/token/kopplung/ — Kopplungscode vom Wachenterminal
  /// (Server ab 0.24.0) gegen ein App-Token tauschen. Der Code gilt einmal.
  Future<AuthToken> exchangePairingCode(
    String code, {
    String label = 'Mobile App (Terminal-Kopplung)',
  }) async {
    final response = await _send(
      _client.post(
        _uri('/api/v1/token/kopplung/'),
        headers: _headers(auth: false),
        body: jsonEncode({'code': code, 'label': label}),
      ),
    );
    final body = _decode(response);
    final value = body['token'] as String?;
    if (value == null || value.isEmpty) {
      throw ApiException(response.statusCode, 'Kein Token in der Antwort.');
    }
    return AuthToken(
      value: value,
      expiresAt: _parseExpiresAt(body['expires_at']),
    );
  }

  /// DELETE /api/v1/token/ — revoke the current app token.
  ///
  /// 401 is treated as success so logout still completes after an already
  /// expired or previously revoked token.
  Future<void> revokeCurrentToken() async {
    if (token == null || token!.isEmpty) {
      return;
    }
    await _withRetry(() async {
      final response = await _send(
        _client.delete(_uri('/api/v1/token/'), headers: _headers()),
      );
      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 401) {
        return;
      }
      _decode(response);
    }, maxAttempts: 1);
  }

  /// GET /api/v1/me/ with encrypted offline fallback.
  Future<Map<String, dynamic>> me() =>
      _getJson('/api/v1/me/', cacheKey: 'me', onOnline: _applyRole);

  /// GET /api/v1/fahrzeuge/sperren/ – laufende Desinfektionssperren der
  /// Fahrzeuge, die die angemeldete Person besetzt. Ältere Server ohne diesen
  /// Endpunkt liefern 404; dann gibt es schlicht nichts zu planen.
  Future<List<VehicleLock>> vehicleLocks() async {
    final body = await _getOptionalJson('/api/v1/fahrzeuge/sperren/');
    return _readList(body)
        .map(VehicleLock.fromJson)
        .where((lock) => lock.lockedUntil != null && lock.key.isNotEmpty)
        .toList(growable: false);
  }

  /// GET /api/v1/benachrichtigungen/ – persönlicher Posteingang.
  Future<List<CrewNotice>> crewNotices() async {
    final body = await _getOptionalJson('/api/v1/benachrichtigungen/');
    return _readList(body).map(CrewNotice.fromJson).toList(growable: false);
  }

  /// POST /api/v1/benachrichtigungen/{id}/gelesen/
  Future<void> markCrewNoticeRead(int id) async {
    await _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/benachrichtigungen/$id/gelesen/'),
          headers: _headers(),
        ),
      );
      if (response.statusCode == 404) return;
      _decode(response);
    }, maxAttempts: 1);
  }

  Future<Map<String, dynamic>> _getOptionalJson(String path) async {
    final response = await _send(_client.get(_uri(path), headers: _headers()));
    if (response.statusCode == 404 || response.statusCode == 501) {
      return const {'results': []};
    }
    return _decode(response);
  }

  /// Höchstzahl an Folgeseiten, die eine Liste nachlädt (Schutz vor Endlosschleifen).
  static const int maxFollowPages = 10;

  /// Liest `next` aus einer Listenantwort – nur relative Pfade unter
  /// `/api/v1/` oder absolute Adressen desselben Servers. Fremde Hosts
  /// bekämen sonst das Token.
  String? nextPagePath(Map<String, dynamic> body) {
    final raw = body['next'];
    if (raw is! String || raw.trim().isEmpty) return null;
    final next = raw.trim();
    if (next.startsWith('/api/v1/')) return next;
    final parsed = Uri.tryParse(next);
    final base = Uri.tryParse(baseUrl);
    if (parsed == null || base == null || !parsed.hasScheme) return null;
    if (parsed.scheme != base.scheme ||
        parsed.host != base.host ||
        parsed.port != base.port ||
        !parsed.path.startsWith('/api/v1/')) {
      return null;
    }
    return parsed.hasQuery ? '${parsed.path}?${parsed.query}' : parsed.path;
  }

  /// Erste Seite plus alle Folgeseiten über `next`. Nur die erste Seite darf
  /// in den Offline-Cache ([cacheKey]); Folgeseiten nie.
  Future<List<Map<String, dynamic>>> _getAllPages(
    String path, {
    String? cacheKey,
    String? moduleLabel,
  }) async {
    var body = await _getJson(path, cacheKey: cacheKey, moduleLabel: moduleLabel);
    final items = [..._readList(body)];
    final seen = <String>{path};
    for (var page = 0; page < maxFollowPages; page++) {
      final next = nextPagePath(body);
      if (next == null || !seen.add(next)) break;
      body = await _getJson(next, moduleLabel: moduleLabel);
      items.addAll(_readList(body));
    }
    return items;
  }

  /// GET /api/v1/handovers/ with encrypted offline fallback.
  Future<List<Map<String, dynamic>>> handovers() async {
    return _getAllPages('/api/v1/handovers/', cacheKey: 'handovers');
  }

  /// POST /api/v1/handovers/ — Felder wie `HandoverForm` des Servers
  /// (Inhaltsrollen). Keine automatische Wiederholung, damit keine
  /// Doppel-Übergaben entstehen.
  Future<Map<String, dynamic>> createHandover({
    required String title,
    required String details,
    required String category,
    String priority = 'normal',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/handovers/'),
          headers: _headers(),
          body: jsonEncode({
            'title': title,
            'details': details,
            'category': category,
            'priority': priority,
          }),
        ),
      );
      return _decode(response);
    }, maxAttempts: 1);
  }

  /// POST /api/v1/handovers/{id}/status/ — `{"status": ...}`, nur
  /// Schichtleitung und Admin. Der Server liefert die Übergabe mit Details und
  /// neuer `version` zurück. Ein unveränderter Status ist dort ein No-op; die
  /// App wiederholt den Aufruf trotzdem nicht automatisch (Grundregel für alle
  /// Schreibaufrufe: kein stilles Wiederholen nach verlorener Antwort).
  Future<Map<String, dynamic>> setHandoverStatus(int id, String status) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/handovers/$id/status/'),
          headers: _headers(),
          body: jsonEncode({'status': status}),
        ),
      );
      return _decode(response);
    }, maxAttempts: 1);
  }

  /// GET /api/v1/handovers/{id}/ — nie offline gespeichert (Freitext).
  Future<Map<String, dynamic>> handoverDetail(int id) =>
      _getJson('/api/v1/handovers/$id/');

  /// POST /api/v1/kaffeekasse/bezahlt/ – „Ich habe bezahlt“ (eigene Zahlung).
  /// Nicht wiederholen: eine doppelte Meldung wäre eine doppelte Buchung.
  Future<void> reportCoffeePayment({
    required String method,
    required num amountEuros,
    String note = '',
  }) async {
    final response = await _send(
      _client.post(
        _uri('/api/v1/kaffeekasse/bezahlt/'),
        headers: _headers(),
        body: jsonEncode({
          'method': method,
          'amount_euros': amountEuros.toStringAsFixed(2),
          if (note.isNotEmpty) 'note': note,
        }),
      ),
    );
    _decode(_requireModule(response, 'Kaffeekasse'));
  }

  /// GET /api/v1/kalender/
  Future<List<KalenderEntry>> kalender() async {
    final body = await _getJson('/api/v1/kalender/');
    return _readList(body).map(KalenderEntry.fromJson).toList(growable: false);
  }

  /// POST /api/v1/kalender/ – Termin anlegen (Schichtleitung und Admin).
  Future<KalenderEntry> createKalenderEntry({
    required String title,
    String description = '',
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/kalender/'),
          headers: _headers(),
          body: jsonEncode({
            'title': title,
            'description': description,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt.toUtc().toIso8601String(),
          }),
        ),
      );
      return KalenderEntry.fromJson(_decode(_requireModule(response, 'Kalender')));
    }, maxAttempts: 1);
  }

  /// GET /api/v1/kaffeekasse/
  Future<Kaffeekasse> kaffeekasse() async {
    // Kaffeekasse ist im Offline-Cache ausdrücklich verboten.
    final body = await _getJson('/api/v1/kaffeekasse/');
    return Kaffeekasse.fromJson(body);
  }

  /// GET /api/v1/checklisten/
  Future<List<Checklist>> checklisten() async {
    final body = await _getJson('/api/v1/checklisten/', cacheKey: 'checklists');
    return _readList(body).map(Checklist.fromJson).toList(growable: false);
  }

  /// GET /api/v1/pinnwand/
  Future<List<PinboardNote>> pinboard() async {
    final body = await _getJson(
      '/api/v1/pinnwand/',
      moduleLabel: 'Pinnwand',
    );
    return _readList(body).map(PinboardNote.fromJson).toList(growable: false);
  }

  /// POST /api/v1/pinnwand/ (create a short station notice).
  Future<PinboardNote> createPinboardNote({
    required String title,
    required String body,
    String category = 'info',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/pinnwand/'),
          headers: _headers(),
          body: jsonEncode({
            'title': title,
            'body': body,
            'category': category,
          }),
        ),
      );
      return PinboardNote.fromJson(_decode(_requireModule(response, 'Pinnwand')));
    }, maxAttempts: 1);
  }

  /// POST /api/v1/checklisten/{id}/abschluss/
  Future<Checklist> checklisteAbschluss(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/checklisten/$id/abschluss/'),
          headers: _headers(),
        ),
      );
      final body = _decode(response);
      if (body.isEmpty) return Checklist(id: id, title: '', completed: true);
      // Antwort beschreibt den Abschluss, nicht die Liste: `created_at` ist
      // der Abschlusszeitpunkt. Titel/Punkte ergänzt der Aufrufer.
      final by = body['completed_by'];
      return Checklist.fromJson({
        ...body,
        'id': body['checklist'] ?? id,
        'completed': true,
        'completed_at': body['created_at'] ?? body['completed_at'],
        'last_completed_by': by is Map ? by['display_name'] : by,
      });
    }, maxAttempts: 1);
  }

  Future<Map<String, dynamic>> setChecklistSchedule(
    int id, {
    required String interval,
    DateTime? dueNext,
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.put(
          _uri('/api/v1/checklisten/$id/schedule/'),
          headers: _headers(),
          body: jsonEncode({
            'interval': interval,
            'due_next': dueNext?.toUtc().toIso8601String(),
          }),
        ),
      );
      return _decode(response);
    }, maxAttempts: 1);
  }

  /// GET /api/v1/defects/
  Future<List<Defect>> defects() async {
    final items = await _getAllPages(
      '/api/v1/defects/',
      moduleLabel: 'Mängel',
    );
    return items.map(Defect.fromJson).toList(growable: false);
  }

  /// GET /api/v1/defects/?active=1&limit=… — erste Seite, sortiert vom
  /// Server (offen → in Arbeit → wartend → erledigt, dann nach Priorität).
  /// Ohne [includeDone] schließt `active=1` erledigte Mängel aus.
  Future<DefectPage> defectsPage({bool includeDone = false, int limit = 100}) async {
    final path = Uri(
      path: '/api/v1/defects/',
      queryParameters: {
        if (!includeDone) 'active': '1',
        'limit': '${limit.clamp(1, 200)}',
      },
    ).toString();
    return _defectPage(await _getJson(path, moduleLabel: 'Mängel'));
  }

  /// Folgt dem `next`-Pfad einer [DefectPage]. Nur Pfade unter
  /// `/api/v1/defects/` auf diesem Server werden angefragt.
  Future<DefectPage> defectsNext(String next) async {
    final path = _sameOriginPath(next, '/api/v1/defects/');
    if (path == null) {
      throw ApiException(400, 'Ungültiger Folgelink vom Server.');
    }
    return _defectPage(await _getJson(path, moduleLabel: 'Mängel'));
  }

  DefectPage _defectPage(Map<String, dynamic> body) {
    final items = _readList(body).map(Defect.fromJson).toList(growable: false);
    String? link(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return DefectPage(
      items: items,
      count: body['count'] is num ? (body['count'] as num).toInt() : items.length,
      next: link(body['next']),
      previous: link(body['previous']),
    );
  }

  /// Pfad samt Query eines Folgelinks, wenn er auf diesen Server und unter
  /// [prefix] zeigt; sonst `null`.
  String? _sameOriginPath(String link, String prefix) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    if (uri.hasScheme || uri.hasAuthority) {
      final base = Uri.tryParse(baseUrl);
      if (base == null ||
          uri.scheme != base.scheme ||
          uri.host != base.host ||
          uri.port != base.port) {
        return null;
      }
    }
    if (!uri.path.startsWith(prefix)) return null;
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }

  Future<Defect> createDefect({
    required String title,
    String description = '',
    String assetRef = '',
    String priority = 'normal',
    String category = 'task',
    String? owner,
    DateTime? dueAt,
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/defects/'),
          headers: _headers(),
          body: jsonEncode({
            'title': title,
            'description': description,
            'asset_ref': assetRef,
            'priority': priority,
            'category': category,
            if (owner != null && owner.isNotEmpty) 'owner': owner,
            if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
          }),
        ),
      );
      return Defect.fromJson(_decode(_requireModule(response, 'Mängel')));
    }, maxAttempts: 1);
  }

  /// PATCH /api/v1/defects/{id}/ – Beschreibung, Bezug, Priorität, Frist
  /// (Inhaltsrollen). Der Titel bleibt auf dem Server unveränderlich.
  /// Keine automatische Wiederholung: Der Server schreibt bei jedem Aufruf
  /// ein Mangel-Ereignis und einen Audit-Eintrag (append-only), eine
  /// Wiederholung nach verlorener Antwort würde sie verdoppeln.
  Future<Defect> updateDefect(
    int id, {
    String? description,
    String? assetRef,
    String? priority,
    DateTime? dueAt,
    bool clearDue = false,
  }) async {
    final body = <String, dynamic>{
      'description': ?description,
      'asset_ref': ?assetRef,
      'priority': ?priority,
      if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      if (clearDue && dueAt == null) 'due_at': null,
    };
    return _withRetry(() async {
      final response = await _send(
        _client.patch(_uri('/api/v1/defects/$id/'), headers: _headers(), body: jsonEncode(body)),
      );
      return Defect.fromJson(_decode(_requireModule(response, 'Mängel')));
    }, maxAttempts: 1);
  }

  /// POST /api/v1/defects/{id}/status/
  /// The server suppresses duplicate status events, so retry is safe.
  Future<Defect> updateDefectStatus(int id, String status) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/defects/$id/status/'),
          headers: _headers(),
          body: jsonEncode({'status': status}),
        ),
      );
      final body = _decode(_requireModule(response, 'Mängel'));
      return Defect.fromJson(body.isEmpty ? {'id': id, 'status': status} : body);
    });
  }

  Future<List<DefectAttachment>> defectAttachments(int defectId) async {
    final body = await _getJson(
      '/api/v1/defects/$defectId/attachments/',
      moduleLabel: 'Mängel',
    );
    return _readList(body)
        .map(DefectAttachment.fromJson)
        .toList(growable: false);
  }

  Future<DefectAttachment> uploadDefectAttachment(
    int defectId, {
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    // Grenze wie der Server (core/api/wachalltag.py: MAX_ATTACHMENT_BYTES).
    if (bytes.length > 5 * 1024 * 1024) {
      throw ApiException(413, 'Bild darf maximal 5 MiB groß sein.');
    }
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/defects/$defectId/attachments/'),
          headers: _headers(),
          body: jsonEncode({
            'filename': filename,
            'content_type': contentType,
            'data_base64': base64Encode(bytes),
          }),
        ),
      );
      return DefectAttachment.fromJson(
        _decode(_requireModule(response, 'Mängel')),
      );
    }, maxAttempts: 1);
  }

  Future<Uint8List> downloadAttachment(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/attachments/$id/'), headers: _headers()),
      );
      if (response.statusCode >= 400) {
        _decode(response);
      }
      return response.bodyBytes;
    });
  }

  /// GET /api/v1/assets/
  Future<List<StationAsset>> assets() async {
    final body = await _getJson(
      '/api/v1/assets/',
      moduleLabel: 'Geräte',
    );
    return _readList(body)
        .map(StationAsset.fromJson)
        .toList(growable: false);
  }

  Future<StationAsset> createAsset({
    required String id,
    required String label,
    String kind = 'device',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/assets/'),
          headers: _headers(),
          body: jsonEncode({'id': id, 'label': label, 'kind': kind}),
        ),
      );
      return StationAsset.fromJson(_decode(_requireModule(response, 'Geräte')));
    }, maxAttempts: 1);
  }

  Future<StationAsset> updateAssetStatus(
    String id, {
    required String status,
    String note = '',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/assets/$id/status/'),
          headers: _headers(),
          body: jsonEncode({'status': status, 'note': note}),
        ),
      );
      return StationAsset.fromJson(_decode(_requireModule(response, 'Geräte')));
    }, maxAttempts: 1);
  }

  /// GET /api/v1/inventory/
  Future<List<InventoryItem>> inventory() async {
    final body = await _getJson(
      '/api/v1/inventory/',
      moduleLabel: 'Inventar',
    );
    return _readList(body)
        .map(InventoryItem.fromJson)
        .toList(growable: false);
  }

  Future<InventoryItem> createInventoryItem({
    required String id,
    required String label,
    String kind = 'device',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/inventory/'),
          headers: _headers(),
          body: jsonEncode({'id': id, 'label': label, 'kind': kind}),
        ),
      );
      return InventoryItem.fromJson(_decode(_requireModule(response, 'Inventar')));
    }, maxAttempts: 1);
  }

  /// Idempotent server-side for the same user/item; safe to retry.
  Future<InventoryItem> inventoryCheckout(String id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/inventory/$id/checkout/'),
          headers: _headers(),
        ),
      );
      final body = _decode(_requireModule(response, 'Inventar'));
      return InventoryItem.fromJson(body.isEmpty ? {'id': id} : body);
    });
  }

  /// Idempotent server-side after a successful return; safe to retry.
  Future<InventoryItem> inventoryCheckin(String id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/inventory/$id/checkin/'),
          headers: _headers(),
        ),
      );
      final body = _decode(_requireModule(response, 'Inventar'));
      return InventoryItem.fromJson(body.isEmpty ? {'id': id} : body);
    });
  }

  Future<List<HandoverAck>> handoverAcks(int id) async {
    final body = await _getJson(
      '/api/v1/handovers/$id/acks/',
      moduleLabel: 'Quittierung',
    );
    return _readList(body).map(HandoverAck.fromJson).toList(growable: false);
  }

  /// Idempotent per handover/user via the server uniqueness constraint.
  Future<HandoverAck> acknowledgeHandover(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/handovers/$id/ack/'),
          headers: _headers(),
          body: jsonEncode(const <String, dynamic>{}),
        ),
      );
      final body = _decode(_requireModule(response, 'Quittierung'));
      if (body.isEmpty) {
        return HandoverAck(handoverId: id, by: '', at: DateTime.now());
      }
      return HandoverAck.fromJson({
        ...body,
        'handover_id': body['handover_id'] ?? id,
      });
    });
  }

  Future<WachalltagReport> reportStats() async {
    final body = await _getJson(
      '/api/v1/reports/',
      moduleLabel: 'Auswertung',
    );
    return WachalltagReport.fromJson(body);
  }

  // --- E2EE messaging -------------------------------------------------------
  // The server only ever stores/forwards ciphertext envelopes; encryption and
  // decryption happen locally in `crypto/e2ee`.

  /// GET /api/v1/chat/identity/ — own key bundle (or `configured: false`).
  Future<Map<String, dynamic>> chatIdentity() =>
      _getJson('/api/v1/chat/identity/');

  /// POST /api/v1/chat/identity/ — register or replace the E2EE identity.
  Future<void> registerChatIdentity({
    required Map<String, dynamic> publicJwk,
    required String wrappedPrivateJwk,
    required String kdfSalt,
    required int kdfIterations,
    bool replace = false,
  }) async {
    await _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/chat/identity/'),
          headers: _headers(),
          body: jsonEncode({
            'public_jwk': publicJwk,
            'wrapped_private_jwk': wrappedPrivateJwk,
            'kdf_salt': kdfSalt,
            'kdf_iterations': kdfIterations,
            if (replace) 'replace': true,
          }),
        ),
      );
      _decode(response);
    }, maxAttempts: 1);
  }

  /// GET /api/v1/chat/keys/ — public keys of station members.
  Future<List<ChatMemberKey>> chatMemberKeys() async {
    final body = await _getJson('/api/v1/chat/keys/', moduleLabel: 'Nachrichten');
    final members = body['members'];
    if (members is! List) return const [];
    return members
        .whereType<Map>()
        .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// GET /api/v1/chat/ — station chat feed (oldest first), ciphertext envelopes.
  Future<List<ChatFeedItem>> stationChat() async {
    final body = await _getJson('/api/v1/chat/', moduleLabel: 'Nachrichten');
    return _readList(body).map(ChatFeedItem.fromJson).toList(growable: false);
  }

  /// POST /api/v1/chat/ — send a pre-encrypted station chat envelope.
  Future<void> sendStationChat(Map<String, dynamic> payload) =>
      _postEnvelope('/api/v1/chat/', payload);

  /// GET /api/v1/chat/private/ — conversations plus colleague key directory.
  Future<PrivateHome> privateConversations() async {
    final body = await _getJson('/api/v1/chat/private/', moduleLabel: 'Nachrichten');
    final colleagues = (body['colleagues'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return PrivateHome(
      conversations:
          _readList(body).map(ChatConversation.fromJson).toList(growable: false),
      colleagues: colleagues,
    );
  }

  /// POST /api/v1/chat/private/ — open (or reuse) a 1:1 conversation.
  Future<int> startPrivateConversation(int peerId) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/chat/private/'),
          headers: _headers(),
          body: jsonEncode({'peer_id': peerId}),
        ),
      );
      final body = _decode(_requireModule(response, 'Nachrichten'));
      return (body['id'] as num).toInt();
    }, maxAttempts: 1);
  }

  /// GET /api/v1/chat/private/{id}/ — thread with peer keys and messages.
  Future<PrivateThreadData> privateThread(int id) async {
    final body = await _getJson('/api/v1/chat/private/$id/', moduleLabel: 'Nachrichten');
    final other = body['other'] is Map ? Map<String, dynamic>.from(body['other']) : const {};
    final peerKeys = (body['peer_keys'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return PrivateThreadData(
      otherId: _readIntValue(other['id']),
      otherName: (other['name'] ?? '').toString(),
      peerKeys: peerKeys,
      messages: _readList(body).map(ChatFeedItem.fromJson).toList(growable: false),
    );
  }

  /// POST /api/v1/chat/private/{id}/ — send a pre-encrypted private message.
  Future<void> sendPrivateMessage(int id, Map<String, dynamic> payload) =>
      _postEnvelope('/api/v1/chat/private/$id/', payload);

  /// GET /api/v1/post/ — Secure Mail inbox/outbox and colleague directory.
  Future<MailInboxData> mailInbox() async {
    final body = await _getJson('/api/v1/post/', moduleLabel: 'Nachrichten');
    List<ChatMemberKey> keys(Object? raw) => (raw as List? ?? const [])
        .whereType<Map>()
        .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    List<MailSummary> mails(Object? raw) => (raw as List? ?? const [])
        .whereType<Map>()
        .map((m) => MailSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return MailInboxData(
      received: mails(body['received']),
      sent: mails(body['sent']),
      colleagues: keys(body['colleagues']),
    );
  }

  /// POST /api/v1/post/ — send Secure Mail (envelope + recipient ids).
  Future<int> sendMail({
    required List<int> recipientIds,
    required Map<String, dynamic> payload,
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/post/'),
          headers: _headers(),
          body: jsonEncode({...payload, 'recipient_ids': recipientIds}),
        ),
      );
      final body = _decode(_requireModule(response, 'Nachrichten'));
      return (body['id'] as num).toInt();
    }, maxAttempts: 1);
  }

  /// GET /api/v1/post/{id}/ — one mail (marks read) with recipient status.
  Future<MailDetailData> mailDetail(int id) async {
    final body = await _getJson('/api/v1/post/$id/', moduleLabel: 'Nachrichten');
    final envelope = body['envelope'] is Map
        ? ChatFeedItem.fromJson(Map<String, dynamic>.from(body['envelope']))
        : const ChatFeedItem(
            id: 0, authorId: null, authorName: '', isOwn: false, isEncrypted: true);
    final recipients = (body['recipients'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => MailRecipientStatus.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return MailDetailData(envelope: envelope, recipients: recipients);
  }

  /// GET /api/v1/chat/groups/ — group rooms the user belongs to.
  Future<List<ChatGroupSummary>> chatGroups() async {
    final body = await _getJson('/api/v1/chat/groups/', moduleLabel: 'Nachrichten');
    return _readList(body).map(ChatGroupSummary.fromJson).toList(growable: false);
  }

  /// POST /api/v1/chat/groups/ — create a group with initial members.
  Future<int> createChatGroup({required String name, required List<int> memberIds}) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/chat/groups/'),
          headers: _headers(),
          body: jsonEncode({'name': name, 'member_ids': memberIds}),
        ),
      );
      final body = _decode(_requireModule(response, 'Nachrichten'));
      return (body['id'] as num).toInt();
    }, maxAttempts: 1);
  }

  /// GET /api/v1/chat/groups/{id}/ — members (with keys) and messages.
  Future<GroupThreadData> groupThread(int id) async {
    final body = await _getJson('/api/v1/chat/groups/$id/', moduleLabel: 'Nachrichten');
    final members = (body['members'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    return GroupThreadData(
      id: _readIntValue(body['id']),
      name: (body['name'] ?? '').toString(),
      isManager: body['is_manager'] == true,
      members: members,
      messages: _readList(body).map(ChatFeedItem.fromJson).toList(growable: false),
    );
  }

  /// POST /api/v1/chat/groups/{id}/ — send a pre-encrypted group message.
  Future<void> sendGroupMessage(int id, Map<String, dynamic> payload) =>
      _postEnvelope('/api/v1/chat/groups/$id/', payload);

  /// POST /api/v1/chat/groups/{id}/members/ — add/remove members (manager only).
  Future<List<ChatMemberKey>> updateGroupMembers(
    int id, {
    List<int> add = const [],
    List<int> remove = const [],
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/chat/groups/$id/members/'),
          headers: _headers(),
          body: jsonEncode({'add': add, 'remove': remove}),
        ),
      );
      final body = _decode(_requireModule(response, 'Nachrichten'));
      return (body['members'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ChatMemberKey.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }, maxAttempts: 1);
  }

  Future<void> _postEnvelope(String path, Map<String, dynamic> payload) async {
    await _withRetry(() async {
      final response = await _send(
        _client.post(_uri(path), headers: _headers(), body: jsonEncode(payload)),
      );
      _decode(_requireModule(response, 'Nachrichten'));
    }, maxAttempts: 1);
  }

  /// Turns module-disabled 404 into a clear, non-retryable ApiException.
  http.Response _requireModule(http.Response response, String label) {
    if (response.statusCode == 404) {
      // Preserve a server-provided canonical error when possible.
      try {
        _decode(response);
      } on ApiException catch (error) {
        if (error.message.isNotEmpty) rethrow;
      }
      throw ApiException(
        404,
        '$label-Modul auf diesem Server nicht verfügbar.',
      );
    }
    return response;
  }

  /// Optional modules that are not installed on older servers.
  static bool isModuleUnavailable(ApiException error) =>
      error.statusCode == 404 || error.statusCode == 501;

  int _readIntValue(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> body) {
    final results = body['results'] ?? body['entries'] ?? body['termine'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  void close() {
    _client.close();
  }

  WachbuchApi copyWithToken(String newToken) {
    return WachbuchApi(
      baseUrl: baseUrl,
      token: newToken,
      client: _client,
      requestTimeout: requestTimeout,
      cache: _cache,
      onUnauthorized: onUnauthorized,
      clock: _clock,
    );
  }
}

/// Validates that a discovery payload looks like a Wachwerk API root.
void ensureWachbuchDiscovery(Map<String, dynamic> body) {
  final endpoints = body['endpoints'];
  final hasTokenEndpoint =
      endpoints is Map &&
      (endpoints.containsKey('token') || endpoints.containsKey('anmeldung'));
  final ok = body['ok'] == true || body['ok'] == 'true';
  final hasVersion =
      body['api_version'] != null ||
      body['version'] != null ||
      body['name'] != null;
  if (!ok && !hasTokenEndpoint && !hasVersion) {
    throw ApiException(
      0,
      'Die Adresse antwortet nicht wie ein Wachwerk-Server (/api/v1/).',
    );
  }
}

DateTime? _parseExpiresAt(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String normalizeServerUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    throw ArgumentError('Server-URL fehlt.');
  }
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

String moduleLabel(String key, {String languageCode = 'de'}) {
  const de = <String, String>{
    'calendar': 'Kalender',
    'birthdays': 'Geburtstage',
    'coffee': 'Kaffeekasse',
    'feeds': 'Meldungen & Verkehr',
    'checklists': 'Checklisten',
    'messaging': 'Nachrichten',
    'chat': 'Wachenchat',
    'pinboard': 'Pinnwand',
    'holidays': 'Feiertage',
    'weather': 'Wetter',
    'tasks': 'Aufgaben',
    'defects': 'Mängel',
    'assets': 'Geräte',
    'inventory': 'Schlüssel & Pools',
    'reports': 'Auswertung',
    'attachments': 'Fotos',
  };
  const en = <String, String>{
    'calendar': 'Calendar',
    'birthdays': 'Birthdays',
    'coffee': 'Coffee fund',
    'feeds': 'News & traffic',
    'checklists': 'Checklists',
    'messaging': 'Messages',
    'chat': 'Station chat',
    'pinboard': 'Pinboard',
    'holidays': 'Public holidays',
    'weather': 'Weather',
    'tasks': 'Tasks',
    'defects': 'Defects',
    'assets': 'Assets',
    'inventory': 'Keys & pools',
    'reports': 'Reports',
    'attachments': 'Photos',
  };
  final labels = languageCode == 'en' ? en : de;
  return labels[key] ?? key;
}
