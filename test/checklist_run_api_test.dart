import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/state/checklist_run.dart';

/// Checklisten mit Ergebnis je Prüfpunkt (Server 0.28, `core/api/views.py`:
/// `checklists_api`, `checklist_complete_api`, `checklist_draft_api`).
class _MemoryCache implements ApiCache {
  final Map<String, Map<String, dynamic>> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = values[key];
    return value == null
        ? null
        : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    values[key] = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<DateTime?> lastUpdatedAt() async => null;

  @override
  Future<DateTime?> oldestOrLatestTimestamp() async => null;
}

const _me = {
  'ok': true,
  'user': {'id': 7, 'username': 'alex'},
  'membership': {
    'role': 'member',
    'station': {
      'id': 3,
      'name': 'RW Nord',
      'modules': {'checklists': true},
    },
  },
};

/// Antwortform von `GET /api/v1/checklisten/` ab 0.28: Kennungen der
/// Prüfpunkte beginnen bewusst nicht bei 1 (Befund G2).
const _list028 = {
  'ok': true,
  'results': [
    {
      'id': 5,
      'title': 'Kühlschrank- & Geräteprüfung',
      'description': 'Morgens',
      'items': ['Kühlschrank Temperatur', 'Plombe intakt', 'Zusatzheizung'],
      'item_details': [
        {
          'id': 42,
          'text': 'Kühlschrank Temperatur',
          'position': 1,
          'required': true,
          'unit': '°C',
          'min': '2.00',
          'max': '8.00',
          'measurement': true,
        },
        {
          'id': 43,
          'text': 'Plombe intakt',
          'position': 2,
          'required': true,
          'unit': '',
          'min': null,
          'max': null,
          'measurement': false,
        },
        {
          'id': 44,
          'text': 'Zusatzheizung',
          'position': 3,
          'required': false,
          'unit': '',
          'min': '0.00',
          'max': null,
          'measurement': true,
        },
      ],
      'requires_personal_login': true,
      'last_completed_at': null,
      'last_completed_by': null,
      'last_completed_paper_backfill': false,
      'draft': {
        'id': 9,
        'note': 'Notiz im Zwischenstand',
        'item_results': {
          '42': {
            'status': 'ok',
            'value': 5.2,
            'reason': '',
            'text': 'Kühlschrank Temperatur',
          },
          '43': {
            'status': 'na',
            'value': null,
            'reason': 'Begründung im Zwischenstand',
            'text': 'Plombe intakt',
          },
        },
        'created_at': '2026-11-09T06:00:00+00:00',
        'updated_at': '2026-11-09T06:10:00+00:00',
        'updated_by': 'Alex Muster',
      },
      'interval': 'daily',
      'due_next': '2026-11-10T06:00:00+00:00',
      'overdue': false,
    },
  ],
};

void main() {
  group('Checklist.fromJson (0.28)', () {
    test(
      'liest item_details mit echten Kennungen, Pflicht und Grenzwerten',
      () {
        final list = Checklist.fromJson(
          Map<String, dynamic>.from((_list028['results'] as List).first as Map),
        );
        expect(list.hasItemDetails, isTrue);
        expect(list.supportsItemResults, isTrue);
        expect(list.requiresPersonalLogin, isTrue);
        expect(list.items.map((item) => item.serverId), [42, 43, 44]);
        final temp = list.items.first;
        expect(temp.required, isTrue);
        expect(temp.unit, '°C');
        expect(temp.min, 2.0);
        expect(temp.max, 8.0);
        expect(temp.measurement, isTrue);
        expect(temp.isOutOfLimits(9), isTrue);
        expect(temp.isOutOfLimits(8), isFalse);
        // 0 ist ein echter Grenzwert.
        expect(list.items[2].min, 0.0);
        expect(list.items[2].isOutOfLimits(-0.5), isTrue);
        expect(list.draft?.updatedBy, 'Alex Muster');
        expect(list.draft?.results[43]?.status, 'na');
        expect(list.draft?.results[42]?.value, 5.2);
      },
    );

    test('ältere Server ohne item_details: keine Server-Kennungen', () {
      final list = Checklist.fromJson({
        'id': 1,
        'title': 'Alt',
        'items': ['A', 'B'],
      });
      expect(list.hasItemDetails, isFalse);
      expect(list.supportsItemResults, isFalse);
      expect(list.items.map((item) => item.serverId), [null, null]);
      expect(list.items.map((item) => item.id), [1, 2]);
    });

    test('Lauf-Antwort mit angelegten und verknüpften Mängeln', () {
      final run = ChecklistRunResult.fromJson({
        'ok': true,
        'id': 77,
        'checklist': 5,
        'is_draft': false,
        'item_results': {
          '42': {
            'status': 'not_ok',
            'value': 9.0,
            'reason': 'Messwert 9 °C außerhalb Grenzwert [2.00..8.00]',
            'text': 'Kühlschrank Temperatur',
            'unit': '°C',
            'defect_id': 12,
            'defect_linked': false,
          },
          '43': {
            'status': 'not_ok',
            'value': null,
            'reason': '',
            'text': 'Plombe intakt',
            'defect_id': 9,
            'defect_linked': true,
          },
        },
        'defects_created': [12],
        'defects_linked': [9],
        'completed_by': {'id': 7, 'username': 'alex', 'display_name': 'Alex'},
        'created_at': '2026-11-09T07:00:00+00:00',
        'occurred_at': null,
        'is_paper_backfill': false,
        'interval': 'daily',
        'due_next': '2026-11-10T06:00:00+00:00',
        'overdue': false,
      });
      expect(run.defectsCreated, [12]);
      expect(run.defectsLinked, [9]);
      expect(run.results[42]?.status, 'not_ok');
      expect(run.results[42]?.defectId, 12);
      expect(run.results[43]?.defectLinked, isTrue);
      expect(run.completedBy, 'Alex');
    });
  });

  group('API', () {
    late List<http.Request> requests;
    late _MemoryCache cache;
    late http.Response Function(http.Request request) respond;

    WachbuchApi api() => WachbuchApi(
      baseUrl: 'https://wache.example',
      token: 'wb_test',
      cache: cache,
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );

    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    setUp(() {
      requests = [];
      cache = _MemoryCache();
      respond = (request) {
        if (request.url.path == '/api/v1/me/') return json(_me);
        if (request.url.path == '/api/v1/checklisten/') return json(_list028);
        return json({'ok': false}, 404);
      };
    });

    test(
      'Zwischenstand landet nie im Offline-Cache, item_details schon',
      () async {
        final client = api();
        await client.me();
        final lists = await client.checklisten();
        expect(lists.single.draft, isNotNull);

        final cached = jsonEncode(cache.values['checklists']);
        expect(cached, isNot(contains('draft')));
        expect(cached, isNot(contains('Begründung im Zwischenstand')));
        expect(cached, isNot(contains('Alex Muster')));
        expect(cached, isNot(contains('Notiz im Zwischenstand')));
        expect(cached, isNot(contains('requires_personal_login')));
        final data =
            cache.values['checklists']!['data'] as Map<String, dynamic>;
        final item = (data['results'] as List).single as Map<String, dynamic>;
        expect((item['item_details'] as List).first, {
          'id': 42,
          'text': 'Kühlschrank Temperatur',
          'position': 1,
          'required': true,
          'unit': '°C',
          'min': '2.00',
          'max': '8.00',
          'measurement': true,
        });
      },
    );

    test('withoutChecklistDrafts entfernt nur results[].draft', () {
      final stripped = WachbuchApi.withoutChecklistDrafts(
        Map<String, dynamic>.from(_list028),
      );
      final item = (stripped['results'] as List).single as Map;
      expect(item.containsKey('draft'), isFalse);
      expect(item['item_details'], isNotEmpty);
      // Die Originalantwort bleibt für die Anzeige unverändert.
      expect(((_list028['results'] as List).single as Map)['draft'], isNotNull);
    });

    test('Offline zeigt die Liste ohne Zwischenstand', () async {
      final client = api();
      await client.me();
      await client.checklisten();
      respond = (_) => throw http.ClientException('offline');
      final offline = await client.checklisten();
      expect(offline.single.draft, isNull);
      expect(offline.single.supportsItemResults, isTrue);
    });

    test(
      'Abschluss sendet nur Server-Kennungen und keinen Wiederholversuch',
      () async {
        respond = (request) => json({
          'ok': true,
          'id': 77,
          'checklist': 5,
          'is_draft': false,
          'item_results': {},
          'defects_created': [],
          'defects_linked': [],
        }, 201);
        final result = await api().completeChecklistRun(
          5,
          results: const {
            42: ChecklistItemResult(status: 'ok', input: '5,2'),
            43: ChecklistItemResult(status: 'na', reason: ' defekt '),
            44: ChecklistItemResult(),
          },
          note: 'Alles gut',
        );
        expect(result.id, 77);
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/checklisten/5/abschluss/');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'item_results': {
            '42': {'status': 'ok', 'value': '5,2', 'reason': ''},
            '43': {'status': 'na', 'value': null, 'reason': 'defekt'},
            '44': {'status': '', 'value': null, 'reason': ''},
          },
          'note': 'Alles gut',
        });
      },
    );

    test('Prüffehler (400) liefern errors je Meldung', () async {
      respond = (request) => json({
        'ok': false,
        'error': {
          'code': 'validation_error',
          'message':
              'Pflichtpunkt „Plombe intakt“ ist nicht ausgefüllt.; Messwert für „Kühlschrank Temperatur“ fehlt.',
          'correlation_id': 'abc',
        },
        'errors': [
          'Pflichtpunkt „Plombe intakt“ ist nicht ausgefüllt.',
          'Messwert für „Kühlschrank Temperatur“ fehlt.',
        ],
      }, 400);
      await expectLater(
        api().completeChecklistRun(5, results: const {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.code, 'code', 'validation_error')
              .having((e) => e.errors, 'errors', hasLength(2)),
        ),
      );
      expect(requests, hasLength(1));
    });

    test('Zwischenstand: GET lädt online, PUT ersetzt', () async {
      respond = (request) {
        if (request.method == 'GET') {
          return json({
            'ok': true,
            'checklist': 5,
            'draft': (((_list028['results'] as List).single as Map)['draft']),
          });
        }
        return json({
          'ok': true,
          'is_draft': true,
          'checklist': 5,
          'draft': {
            'id': 9,
            'note': '',
            'item_results': {},
            'updated_at': '2026-11-09T07:00:00+00:00',
            'updated_by': 'Alex',
          },
        });
      };
      final client = api();
      final draft = await client.checklistDraft(5);
      expect(draft?.results[42]?.value, 5.2);
      final saved = await client.saveChecklistDraft(
        5,
        results: const {42: ChecklistItemResult(status: 'ok', input: '4')},
      );
      expect(saved?.updatedBy, 'Alex');
      expect(requests.map((r) => r.method), ['GET', 'PUT']);
      expect(requests.last.url.path, '/api/v1/checklisten/5/zwischenstand/');
      expect(cache.values, isEmpty);
    });
  });

  group('assignChecklistErrors', () {
    const items = [
      ChecklistItem(id: 42, serverId: 42, label: 'Tür'),
      ChecklistItem(id: 43, serverId: 43, label: 'Türen hinten'),
      ChecklistItem(id: 44, serverId: 44, label: 'Kühlschrank Temperatur'),
    ];

    test(
      'ordnet Meldungen über den vollständigen Text in Anführungszeichen zu',
      () {
        final result = assignChecklistErrors(items, [
          'Pflichtpunkt „Türen hinten“ ist nicht ausgefüllt.',
          'Für entfallenen Punkt „Tür“ ist eine Begründung erforderlich.',
          'Ungültiger Messwert für “Kühlschrank Temperatur”: abc',
          'Unbekannter Prüfpunkt: 999',
          'Für diesen Abschluss fehlen die Ergebnisse je Prüfpunkt. Bitte jeden Prüfpunkt bewerten.',
        ]);
        expect(result.byItem[43], [
          'Pflichtpunkt „Türen hinten“ ist nicht ausgefüllt.',
        ]);
        expect(result.byItem[42], [
          'Für entfallenen Punkt „Tür“ ist eine Begründung erforderlich.',
        ]);
        expect(result.byItem[44], hasLength(1));
        expect(result.general, hasLength(2));
      },
    );
  });
}
