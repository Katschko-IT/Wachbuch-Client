import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/api/client.dart';

/// Umsetzung von docs/CLIENT-OFFLINE-CONTRACT.md (Server-Repository):
/// Positivliste, Datensparsamkeit, 24 h Höchstalter, Rollenausschluss und
/// Lesen nur innerhalb einer online bestätigten Sitzung.
class _MemoryCache implements ApiCache {
  final Map<String, Map<String, dynamic>> values = {};
  var clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    values.clear();
  }

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = values[key];
    return value == null ? null : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    values[key] = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Antwortformen aus core/api/views.py bzw. core/api/wachalltag.py.
Map<String, dynamic> _me(String role) => {
      'ok': true,
      'api_version': 'v1',
      'user': {
        'id': 7,
        'username': 'michael',
        'first_name': 'Michael',
        'last_name': 'K',
      },
      'membership': {
        'role': role,
        'role_label': 'Mitglied',
        'station': {
          'id': 3,
          'name': 'Wache Nord',
          'slug': 'nord',
          'modules': {'checklists': true, 'coffee': true},
        },
      },
      'token': {
        'id': 11,
        'label': 'Mobile App',
        'prefix': 'wb_abcdefgh',
        'scopes': ['read:me'],
      },
    };

class _Server {
  _Server();

  String role = 'member';
  bool online = true;
  final requests = <String>[];

  http.Client get client => MockClient((request) async {
        requests.add(request.url.path);
        if (!online) throw http.ClientException('offline', request.url);
        final path = request.url.path;
        Object body;
        if (path == '/api/v1/me/') {
          body = _me(role);
        } else if (path == '/api/v1/handovers/') {
          body = {
            'ok': true,
            'count': 1,
            'results': [
              {
                'id': 1,
                'title': 'RTW 1 auffüllen',
                'category': 'vehicle',
                'priority': 'urgent',
                'status': 'open',
                'updated_at': '2026-10-24T08:00:00+00:00',
                'details': 'Freitext darf nicht in den Cache.',
              },
            ],
            'next': null,
            'previous': null,
          };
        } else if (path == '/api/v1/handovers/1/') {
          body = {
            'ok': true,
            'id': 1,
            'title': 'RTW 1 auffüllen',
            'details': 'Freitext',
            'version': 1,
          };
        } else if (path == '/api/v1/checklisten/') {
          body = {
            'ok': true,
            'results': [
              {
                'id': 4,
                'title': 'RTW-Check',
                'description': 'Morgens',
                'items': ['Sauerstoff', 'Defi'],
                'last_completed_at': '2026-10-24T06:00:00+00:00',
                'last_completed_by': 'Anna B',
                'interval': 'daily',
                'due_next': '2026-10-25T06:00:00+00:00',
                'overdue': false,
                'note': 'Abschlussnotiz',
              },
            ],
          };
        } else if (path == '/api/v1/kaffeekasse/') {
          body = {'ok': true, 'balance_euros': '12.50', 'results': []};
        } else if (path == '/api/v1/kalender/') {
          body = {'ok': true, 'results': []};
        } else if (path == '/api/v1/defects/') {
          body = {'ok': true, 'count': 0, 'results': []};
        } else if (path == '/api/v1/defects/1/attachments/') {
          body = {'ok': true, 'results': []};
        } else {
          return http.Response('{}', 404);
        }
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json'});
      });
}

void main() {
  late _Server server;
  late _MemoryCache cache;
  late DateTime now;

  WachbuchApi api() => WachbuchApi(
        baseUrl: 'https://wache.example',
        token: 'wb_test',
        client: server.client,
        cache: cache,
        requestTimeout: const Duration(milliseconds: 100),
        clock: () => now,
      );

  setUp(() {
    server = _Server();
    cache = _MemoryCache();
    now = DateTime.utc(2026, 10, 24, 12);
  });

  test('eigene Mitgliedschaft wird datensparsam mit Zeitstempel gespeichert', () async {
    await api().me();

    final entry = cache.values['me']!;
    expect(entry['fetched_at'], now.toIso8601String());
    expect(entry['expires_at'], now.add(const Duration(hours: 24)).toIso8601String());
    final data = entry['data'] as Map<String, dynamic>;
    expect(data.containsKey('token'), isFalse);
    expect(data['membership']['role'], 'member');
    expect(data['membership']['station']['name'], 'Wache Nord');
    expect(data['user']['id'], 7);
  });

  test('Offline-Lesen nach bestätigter Sitzung liefert den Snapshot', () async {
    final client = api();
    await client.me();
    await client.handovers();

    server.online = false;
    final me = await client.me();
    final handovers = await client.handovers();

    expect(me['membership']['station']['name'], 'Wache Nord');
    expect(handovers.single['title'], 'RTW 1 auffüllen');
    expect(handovers.single['priority'], 'urgent');
  });

  test('ohne online bestätigte Sitzung wird kein Cache gelesen', () async {
    await api().me(); // frühere Sitzung hat den Snapshot geschrieben

    server.online = false;
    final coldStart = api();
    await expectLater(
      coldStart.me(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0)),
    );
  });

  test('Übergabeliste wird ohne Freitext gespeichert', () async {
    final client = api();
    await client.me();
    await client.handovers();

    final data = cache.values['handovers']!['data'] as Map<String, dynamic>;
    final item = (data['results'] as List).single as Map<String, dynamic>;
    expect(item.keys.toSet(), {'id', 'title', 'updated_at', 'urgent'});
    expect(item['urgent'], isTrue);
    expect(jsonEncode(cache.values), isNot(contains('Freitext')));
  });

  test('Checklisten ohne Abschlussnotizen', () async {
    final client = api();
    await client.me();
    await client.checklisten();

    final data = cache.values['checklists']!['data'] as Map<String, dynamic>;
    final item = (data['results'] as List).single as Map<String, dynamic>;
    expect(item['items'], ['Sauerstoff', 'Defi']);
    expect(item['last_completed_by'], 'Anna B');
    expect(item.containsKey('note'), isFalse);
  });

  test('Kaffeekasse, Übergabe-Details, Mängel und Anhänge werden nie gespeichert', () async {
    final client = api();
    await client.me();
    await client.kaffeekasse();
    await client.handoverDetail(1);
    await client.defectAttachments(1);
    await client.kalender();

    expect(cache.values.keys.toSet(), {'me'});
  });

  test('Einträge älter als 24 h werden verworfen', () async {
    final client = api();
    await client.me();
    await client.handovers();

    now = now.add(const Duration(hours: 24, minutes: 1));
    server.online = false;
    await expectLater(client.handovers(), throwsA(isA<ApiException>()));
    expect(cache.values.containsKey('handovers'), isFalse);
  });

  test('alte Einträge ohne Zeitstempel werden nicht verwendet', () async {
    final client = api();
    await client.me();
    cache.values['handovers'] = {
      'results': [
        {'id': 9, 'title': 'Altbestand'},
      ],
    };

    server.online = false;
    await expectLater(client.handovers(), throwsA(isA<ApiException>()));
  });

  for (final role in ['admin', 'cashier', 'auditor']) {
    test('kein Cache für Rolle $role', () async {
      cache.values['checklists'] = {'data': {}, 'fetched_at': now.toIso8601String()};
      server.role = role;
      final client = api();
      await client.me();
      await client.checklisten();
      await client.handovers();

      expect(cache.values, isEmpty);
      expect(cache.clears, greaterThan(0));
    });
  }

  test('Rollenwechsel löscht den Cache vollständig', () async {
    final client = api();
    await client.me();
    await client.handovers();
    expect(cache.values.keys, containsAll(['me', 'handovers']));

    server.role = 'shift_lead';
    await api().me();

    expect(cache.values.keys.toSet(), {'me'});
    expect(
      (cache.values['me']!['data'] as Map)['membership']['role'],
      'shift_lead',
    );
  });
}
