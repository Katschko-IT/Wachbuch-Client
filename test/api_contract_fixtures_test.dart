import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/crew_notice.dart';
import 'package:wachbuch_mobile/models/reading_obligation.dart';
import 'package:wachbuch_mobile/state/checklist_run.dart';

/// API-Vertragstest (Befund T1) mit echten Serverantworten.
///
/// Die Dateien unter `test/fixtures/server-0.28/` erzeugt
/// `tool/server_contract/generate_fixtures.py` aus dem Server-Code
/// (Django-Testclient, eingefrorene Uhr). Jede Datei hält `status` und
/// `body` einer Antwort. Die Tests schicken sie durch die echten Aufrufe und
/// Modelle der App: Benennt der Server ein Feld um, schlägt hier ein Test
/// fehl. Auffrischen: docs/API-VERTRAG-FIXTURES.md.
const _dir = 'test/fixtures/server-0.28';

Map<String, dynamic> _fixture(String name) {
  final file = File('$_dir/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _body(String name) =>
    Map<String, dynamic>.from(_fixture(name)['body'] as Map);

/// Liefert für jede Anfrage die Antwort aus [route] (Pfad mit Query → Datei).
WachbuchApi _api(
  Map<String, String> route, {
  List<http.Request>? requests,
  ApiCache? cache,
}) {
  return WachbuchApi(
    baseUrl: 'https://wache.example.org',
    token: 'wb_contract',
    cache: cache,
    client: MockClient((request) async {
      requests?.add(request);
      final query = request.url.hasQuery ? '?${request.url.query}' : '';
      final key = '${request.method} ${request.url.path}$query';
      final name = route[key] ?? route['${request.method} ${request.url.path}'];
      if (name == null) return http.Response('{"ok": false}', 404);
      final fixture = _fixture(name);
      return http.Response(
        jsonEncode(fixture['body']),
        fixture['status'] as int,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

class _MemoryCache implements ApiCache {
  final Map<String, Map<String, dynamic>> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => values[key];

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      values[key] = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<DateTime?> lastUpdatedAt() async => null;

  @override
  Future<DateTime?> oldestOrLatestTimestamp() async => null;
}

void main() {
  test('Discovery: API-Stand 0.28 an den Fähigkeiten erkennbar', () {
    final body = _body('discovery');
    ensureWachbuchDiscovery(body);
    final info = ServerInfo.fromDiscovery(body);
    expect(info.version, isNotNull);
    expect(info.hasApi028, isTrue);
    expect(info.supportsDefectReferenceFilter, isTrue);
  });

  test('/me/: Rolle und Wache für Rechte und Offline-Cache', () async {
    final me = await _api({'GET /api/v1/me/': 'me'}).me();
    expect(OfflineCachePolicy.roleOf(me), 'member');
    final station = (me['membership'] as Map)['station'] as Map;
    expect(station['name'], isNotEmpty);
    expect((station['modules'] as Map)['checklists'], isTrue);
    expect((me['user'] as Map)['id'], isA<int>());
  });

  group('Übergaben', () {
    test('Liste mit Nachtrag vom Papierbogen', () async {
      expect(_body('handover_create')['id'], isA<int>());
      expect(_body('handover_create_backfill')['is_paper_backfill'], isTrue);
      final items = await _api({
        'GET /api/v1/handovers/': 'handovers',
      }).handovers();
      final backfill = items.firstWhere(
        (item) => item['is_paper_backfill'] == true,
      );
      expect(DateTime.tryParse(backfill['occurred_at'] as String), isNotNull);
      final normal = items.firstWhere(
        (item) => item['is_paper_backfill'] == false,
      );
      expect(normal['occurred_at'], isNull);
      for (final item in items) {
        expect(
          item.keys,
          containsAll([
            'id',
            'title',
            'category',
            'priority',
            'status',
            'updated_at',
          ]),
        );
      }
    });

    test(
      'Detail mit Erfassung, Autor und Version; Cache ohne Nachtrag-Felder',
      () async {
        final detail = _body('handover_detail_backfill');
        expect(DateTime.tryParse(detail['created_at'] as String), isNotNull);
        expect(DateTime.tryParse(detail['occurred_at'] as String), isNotNull);
        expect((detail['author'] as Map)['display_name'], isNotEmpty);
        expect(detail['version'], isA<int>());

        final cached = OfflineCachePolicy.minimize(
          'handovers',
          _body('handovers'),
        );
        final text = jsonEncode(cached);
        expect(text, isNot(contains('is_paper_backfill')));
        expect(text, isNot(contains('occurred_at')));
      },
    );
  });

  group('Checklisten', () {
    test(
      'Liste: item_details mit echten Kennungen, Zwischenstand der Wache',
      () {
        final raw = (_body('checklists')['results'] as List).cast<Map>();
        final json = Map<String, dynamic>.from(raw.single);
        final list = Checklist.fromJson(json);
        final details = (json['item_details'] as List).cast<Map>();

        expect(list.supportsItemResults, isTrue);
        expect(list.requiresPersonalLogin, isTrue);
        expect(
          list.items.map((item) => item.serverId),
          details.map((d) => d['id']),
        );
        // Fremde Prüfpunkte wurden zuerst angelegt: keine Listenpositionen.
        expect(list.items.first.serverId, isNot(1));
        final temp = list.items.first;
        expect(temp.required, isTrue);
        expect(temp.unit, '°C');
        expect(temp.min, 2.0);
        expect(temp.max, 8.0);
        expect(temp.measurement, isTrue);
        expect(list.items.last.min, 0.0, reason: '0 ist ein echter Grenzwert');

        final draft = list.draft!;
        expect(draft.updatedBy, isNotEmpty);
        expect(draft.updatedAt, isNotNull);
        expect(draft.note, isNotEmpty);
        expect(draft.results[temp.serverId]!.value, 5.2);
        expect(draft.results[list.items[1].serverId]!.status, 'na');
        expect(draft.results[list.items[1].serverId]!.reason, isNotEmpty);
      },
    );

    test('Offline-Cache: item_details ja, Zwischenstand nie', () async {
      final cache = _MemoryCache();
      final api = _api({
        'GET /api/v1/me/': 'me',
        'GET /api/v1/checklisten/': 'checklists',
      }, cache: cache);
      await api.me();
      final online = await api.checklisten();
      expect(online.single.draft, isNotNull);
      final cached = jsonEncode(cache.values['checklists']);
      expect(cached, isNot(contains('"draft"')));
      expect(cached, isNot(contains('updated_by')));
      final data = cache.values['checklists']!['data'] as Map<String, dynamic>;
      final restored = Checklist.fromJson(
        Map<String, dynamic>.from((data['results'] as List).single as Map),
      );
      expect(restored.supportsItemResults, isTrue);
      expect(restored.draft, isNull);
    });

    test('Zwischenstand lesen und ersetzen', () async {
      final requests = <http.Request>[];
      final list = Checklist.fromJson(
        Map<String, dynamic>.from(
          (_body('checklists')['results'] as List).single as Map,
        ),
      );
      final api = _api({
        'GET /api/v1/checklisten/${list.id}/zwischenstand/': 'checklist_draft',
        'PUT /api/v1/checklisten/${list.id}/zwischenstand/':
            'checklist_draft_put',
      }, requests: requests);
      final loaded = await api.checklistDraft(list.id);
      expect(
        loaded!.results.keys,
        containsAll(list.items.take(2).map((i) => i.serverId)),
      );
      final saved = await api.saveChecklistDraft(
        list.id,
        results: {
          list.items.first.serverId!: const ChecklistItemResult(
            status: 'ok',
            input: '5,2',
          ),
        },
      );
      expect(saved!.updatedBy, isNotEmpty);
      expect(_body('checklist_draft_put')['is_draft'], isTrue);
      expect(requests.map((r) => r.method), ['GET', 'PUT']);
    });

    test(
      'Prüffehler (400): errors lassen sich jedem Prüfpunkt zuordnen',
      () async {
        final list = Checklist.fromJson(
          Map<String, dynamic>.from(
            (_body('checklists')['results'] as List).single as Map,
          ),
        );
        final api = _api({
          'POST /api/v1/checklisten/${list.id}/abschluss/':
              'checklist_run_invalid',
        });
        try {
          await api.completeChecklistRun(list.id, results: const {});
          fail('400 erwartet');
        } on ApiException catch (error) {
          expect(error.statusCode, 400);
          expect(error.code, 'validation_error');
          expect(error.errors, hasLength(3));
          final assigned = assignChecklistErrors(list.items, error.errors);
          expect(assigned.general, isEmpty);
          expect(
            assigned.byItem.keys.toSet(),
            list.items.map((i) => i.serverId).toSet(),
          );
        }
      },
    );

    test(
      'Abschluss: Grenzwert setzt „nicht in Ordnung“, Mangel angelegt',
      () async {
        final list = Checklist.fromJson(
          Map<String, dynamic>.from(
            (_body('checklists')['results'] as List).single as Map,
          ),
        );
        final api = _api({
          'POST /api/v1/checklisten/${list.id}/abschluss/': 'checklist_run',
        });
        final run = await api.completeChecklistRun(list.id, results: const {});
        expect(run.checklistId, list.id);
        expect(run.defectsCreated, isNotEmpty);
        expect(run.completedBy, isNotEmpty);
        final temp = run.results[list.items.first.serverId]!;
        expect(temp.status, ChecklistItemStatus.notOk);
        expect(temp.value, 9.5);
        expect(temp.reason, isNotEmpty);
        expect(temp.defectId, run.defectsCreated.first);
        expect(temp.defectLinked, isFalse);
        expect(run.defectsLinked, isEmpty);

        final after = Checklist.fromJson(
          Map<String, dynamic>.from(
            (_body('checklists_after_run')['results'] as List).single as Map,
          ),
        );
        expect(after.completedAt, isNotNull);
        expect(after.completedBy, isNotEmpty);
        expect(
          after.draft,
          isNull,
          reason: 'Der Abschluss löscht den Zwischenstand',
        );
      },
    );

    test(
      'Zweiter Lauf: offener Mangel wird verknüpft, nicht neu angelegt',
      () async {
        final list = Checklist.fromJson(
          Map<String, dynamic>.from(
            (_body('checklists')['results'] as List).single as Map,
          ),
        );
        final firstDefect =
            (_body('checklist_run')['defects_created'] as List).single as int;
        final api = _api({
          'POST /api/v1/checklisten/${list.id}/abschluss/':
              'checklist_run_linked',
        });
        final run = await api.completeChecklistRun(list.id, results: const {});
        expect(run.defectsCreated, isEmpty);
        expect(run.defectsLinked, [firstDefect]);
        final temp = run.results[list.items.first.serverId]!;
        expect(temp.status, ChecklistItemStatus.notOk);
        expect(temp.defectId, firstDefect);
        expect(temp.defectLinked, isTrue);
        // Eigene Feststellung bleibt; der Server ersetzt sie nicht.
        expect(temp.reason, 'Tür schließt nicht');
        final others = list.items.skip(1).map((i) => run.results[i.serverId]!);
        for (final result in others) {
          expect(result.status, ChecklistItemStatus.ok);
          expect(result.defectId, isNull);
          expect(result.defectLinked, isFalse);
        }
      },
    );
  });

  group('Mängel und Bezüge', () {
    test('Geräte & Fahrzeuge', () async {
      final assets = await _api({'GET /api/v1/assets/': 'assets'}).assets();
      expect(
        assets.map((a) => a.id),
        containsAll(['rtw-1', 'rtw-10', 'defi-2']),
      );
      expect(assets.firstWhere((a) => a.id == 'rtw-1').kind, 'vehicle');
      expect(assets.firstWhere((a) => a.id == 'defi-2').kind, 'device');
      expect(assets.firstWhere((a) => a.id == 'rtw-1').label, 'RTW 1');
    });

    test('Anlegen liefert den Mangel zurück', () async {
      final api = _api({'POST /api/v1/defects/': 'defect_create'});
      final defect = await api.createDefect(
        title: 'Fahrzeug: RTW 1',
        assetRef: 'RTW 1',
      );
      expect(defect.id, greaterThan(0));
      expect(defect.assetRef, 'RTW 1');
      expect(defect.category, 'vehicle');
      expect(defect.priority, 'important');
    });

    test('?asset= exakt: RTW 1 findet nicht RTW 10', () async {
      final requests = <http.Request>[];
      final api = _api({
        'GET /api/v1/defects/?active=1&asset=rtw-1&limit=5':
            'defects_for_reference',
        'GET /api/v1/defects/?active=1&limit=100': 'defects_active',
      }, requests: requests);
      final all = await api.defectsPage();
      expect(all.count, 2);
      final page = await api.defectsForReference('rtw-1');
      expect(requests.last.url.queryParameters, {
        'active': '1',
        'asset': 'rtw-1',
        'limit': '5',
      });
      expect(page.count, 1);
      expect(page.items.single.assetRef, 'RTW 1');
    });

    test('Fehlervertrag 422 bei fehlendem Titel', () async {
      final api = _api({'POST /api/v1/defects/': 'error_defect_validation'});
      await expectLater(
        api.createDefect(title: ''),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.code, 'code', 'validation_error')
              .having((e) => e.correlationId, 'correlation', isNotEmpty),
        ),
      );
    });
  });

  group('Lesepflicht', () {
    test(
      'offene Dienstanweisungen mit Version, Frist und Überfälligkeit',
      () async {
        final requests = <http.Request>[];
        final api = _api({
          'GET /api/v1/dienstanweisungen/?offen=1': 'sops_open',
        }, requests: requests);
        final open = await api.readingObligations();
        expect(open, hasLength(2));
        final overdue = open!.firstWhere((item) => item.overdue);
        expect(overdue.title, 'Händedesinfektion');
        expect(overdue.docNumber, 'DA-HYG-1');
        final later = open.firstWhere((item) => !item.overdue);
        expect(later.title, 'Funkdisziplin');
        expect(later.docNumber, 'DA-FUNK-2');
        expect(overdue.revisionId, isNotNull);
        expect(overdue.revisionVersion, isNotEmpty);
        expect(overdue.ackDueDate, isNotNull);
        expect(overdue.acknowledged, isFalse);
        expect(overdue.url, startsWith('/'));
        expect(api.webPage(overdue.url)?.host, 'wache.example.org');
      },
    );

    test('Bestätigen: 409 bei alter Version, 201 bei aktueller', () async {
      final open = (_body('sops_open')['results'] as List)
          .map(
            (raw) => ReadingObligation.fromJson(
              Map<String, dynamic>.from(raw as Map),
            ),
          )
          .toList();
      final target = open.firstWhere((item) => item.overdue);
      final stale = _api({
        'POST /api/v1/dienstanweisungen/${target.id}/quittieren/':
            'sop_ack_stale_revision',
      });
      await expectLater(
        stale.acknowledgeReadingObligation(target.id, revisionId: 1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.code, 'code', 'conflict'),
        ),
      );
      final ok = _api({
        'POST /api/v1/dienstanweisungen/${target.id}/quittieren/': 'sop_ack',
      });
      final acked = await ok.acknowledgeReadingObligation(
        target.id,
        revisionId: target.revisionId,
      );
      expect(acked.acknowledged, isTrue);
      expect(acked.acknowledgedAt, isNotNull);
      expect(_body('sop_ack')['created'], isTrue);

      final all = (_body('sops_all')['results'] as List).map(
        (raw) =>
            ReadingObligation.fromJson(Map<String, dynamic>.from(raw as Map)),
      );
      expect(all.where((item) => item.acknowledged), hasLength(1));
    });
  });

  group('Hinweise', () {
    test(
      'alle Arten von 0.28 sind bekannt; ?kinds= fragt genau diese ab',
      () async {
        final requests = <http.Request>[];
        final api = _api({
          'GET /api/v1/benachrichtigungen/': 'notifications',
        }, requests: requests);
        final notices = await api.crewNotices();
        expect(
          requests.single.url.queryParameters['kinds']!.split(',').toSet(),
          CrewNotice.shownKinds,
        );
        expect(notices, hasLength(6));
        for (final notice in notices) {
          expect(notice.isShownKind, isTrue, reason: notice.kind);
          expect(notice.key, isNotEmpty);
          expect(notice.title, isNotEmpty);
          expect(notice.createdAt, isNotNull);
        }
        expect(notices.where((n) => n.isWeeklyDigest), hasLength(1));
        // Der Text der MPG-Einweisung nennt eine Person: auf dem Gerät nur
        // neutral (siehe CrewReminderService).
        final mpg = notices.singleWhere(
          (n) => n.kind == CrewNotice.mpgTrainingMissing,
        );
        expect(mpg.mayNamePerson, isTrue);
        expect(mpg.body, contains('Kim Leitung'));
        expect(notices.where((n) => n.mayNamePerson), [
          mpg,
        ], reason: 'nur diese Art nennt eine Person');
        expect(
          notices.where((n) => n.kind == CrewNotice.sopDue).single.url,
          startsWith('/orga/sop/'),
        );
        expect(_body('notifications')['unread_count'], 6);
      },
    );

    test('einzeln als gelesen melden; Fahrzeugsperren', () async {
      final api = _api({
        'POST /api/v1/benachrichtigungen/1/gelesen/': 'notification_read',
        'GET /api/v1/fahrzeuge/sperren/': 'vehicle_locks',
      });
      await api.markCrewNoticeRead(1);
      expect(_body('notification_read')['read'], isTrue);
      expect(await api.vehicleLocks(), isEmpty);
    });
  });

  test('401 meldet die Sitzung als ungültig', () async {
    ApiException? reported;
    final api = WachbuchApi(
      baseUrl: 'https://wache.example.org',
      token: 'wb_contract',
      onUnauthorized: (error) => reported = error,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(_body('error_unauthorized')),
          _fixture('error_unauthorized')['status'] as int,
        ),
      ),
    );
    await expectLater(api.me(), throwsA(isA<ApiException>()));
    expect(reported?.statusCode, 401);
    expect(reported?.code, 'auth_required');
    expect(reported?.isSessionInvalid, isTrue);
  });

  test('jede erzeugte Fixture wird von einem Test gelesen', () {
    final manifest =
        jsonDecode(File('$_dir/_manifest.json').readAsStringSync()) as Map;
    final listed = (manifest['fixtures'] as List).cast<String>().toSet();
    final onDisk = Directory(_dir)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.json') && !name.startsWith('_'))
        .map((name) => name.substring(0, name.length - 5))
        .toSet();
    expect(onDisk, listed);
    expect(manifest['api'], '0.28');
    // Unabhängig von der Reihenfolge der Tests: Jede Datei muss in dieser
    // Testdatei namentlich vorkommen.
    final source = File(
      'test/api_contract_fixtures_test.dart',
    ).readAsStringSync();
    final unused = listed.where((name) => !source.contains("'$name'")).toList();
    expect(unused, isEmpty);
  });
}
