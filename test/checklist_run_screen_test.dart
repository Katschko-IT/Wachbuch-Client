import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/screens/checklist_run_screen.dart';
import 'package:wachbuch_mobile/screens/checklisten_screen.dart';

import 'test_localization.dart';

Checklist _checklist({ChecklistDraft? draft}) => Checklist.fromJson({
  'id': 5,
  'title': 'Kühlschrankprüfung',
  'items': ['Kühlschrank Temperatur', 'Plombe intakt'],
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
  ],
  'requires_personal_login': false,
  'last_completed_at': null,
  'interval': '',
  'due_next': null,
  'overdue': false,
}).copyWith(draft: draft);

class _RunApi extends WachbuchApi {
  _RunApi({this.draft, this.completeError, this.lists})
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  ChecklistDraft? draft;
  ApiException? completeError;
  List<Checklist>? lists;
  final saved = <Map<int, ChecklistItemResult>>[];
  final completed = <Map<int, ChecklistItemResult>>[];
  final notes = <String>[];
  int draftLoads = 0;

  @override
  Future<List<Checklist>> checklisten() async => lists ?? [_checklist()];

  @override
  Future<ChecklistDraft?> checklistDraft(int id) async {
    draftLoads++;
    return draft;
  }

  @override
  Future<ChecklistDraft?> saveChecklistDraft(
    int id, {
    required Map<int, ChecklistItemResult> results,
    String note = '',
  }) async {
    saved.add(results);
    notes.add(note);
    return ChecklistDraft(id: 1, results: results, updatedBy: 'Alex');
  }

  @override
  Future<ChecklistRunResult> completeChecklistRun(
    int id, {
    required Map<int, ChecklistItemResult> results,
    String note = '',
  }) async {
    completed.add(results);
    final error = completeError;
    if (error != null) throw error;
    return ChecklistRunResult.fromJson({
      'id': 77,
      'checklist': id,
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
          'status': 'ok',
          'value': null,
          'reason': '',
          'text': 'Plombe intakt',
          'defect_id': null,
          'defect_linked': false,
        },
      },
      'defects_created': [12],
      'defects_linked': [],
    });
  }

  @override
  Future<DefectPage> defectsPage({
    bool includeDone = false,
    int limit = 100,
  }) async => const DefectPage(items: [], count: 0);

  @override
  Future<Map<String, dynamic>> me() async => {
    'membership': {'role': 'member'},
  };
}

Future<void> _pumpRun(
  WidgetTester tester,
  _RunApi api, {
  Checklist? list,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      home: ChecklistRunScreen(api: api, checklist: list ?? _checklist()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pflicht, Grenzwerte und Hinweis außerhalb der Grenzwerte', (
    tester,
  ) async {
    final api = _RunApi();
    await _pumpRun(tester, api);

    expect(find.text('Kühlschrank Temperatur'), findsOneWidget);
    expect(find.text('Pflicht'), findsNWidgets(2));
    expect(find.text('Grenzwerte 2 °C bis 8 °C'), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-status-42-ok')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('run-value-42')), '9,5');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Außerhalb der Grenzwerte: Beim Abschluss wird der Punkt „nicht in Ordnung“.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('run-status-43-na')));
    await tester.pumpAndSettle();
    expect(find.text('Begründung (Pflicht)'), findsOneWidget);
  });

  testWidgets('Prüffehler erscheinen am Prüfpunkt, Eingaben bleiben erhalten', (
    tester,
  ) async {
    final api = _RunApi(
      completeError: ApiException(
        400,
        'Pflichtpunkt „Plombe intakt“ ist nicht ausgefüllt.',
        code: 'validation_error',
        errors: const ['Pflichtpunkt „Plombe intakt“ ist nicht ausgefüllt.'],
      ),
    );
    await _pumpRun(tester, api);

    await tester.tap(find.byKey(const Key('run-status-42-ok')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('run-value-42')), '5,2');
    await tester.ensureVisible(find.byKey(const Key('run-finish')));
    await tester.tap(find.byKey(const Key('run-finish')));
    await tester.pumpAndSettle();

    expect(api.completed.single[42]?.status, 'ok');
    expect(api.completed.single[42]?.valueText, '5,2');
    expect(api.completed.single.keys, [42, 43]);
    expect(find.byKey(const Key('run-item-error-43')), findsOneWidget);
    expect(find.byKey(const Key('run-item-error-42')), findsNothing);
    expect(
      find.text(
        'Der Server hat den Lauf nicht angenommen. Deine Eingaben sind erhalten.',
      ),
      findsOneWidget,
    );
    // Eingabe ist noch da.
    expect(find.text('5,2'), findsOneWidget);
  });

  testWidgets(
    'Abschluss zeigt die Antwort des Servers und den angelegten Mangel',
    (tester) async {
      final api = _RunApi();
      await _pumpRun(tester, api);

      await tester.tap(find.byKey(const Key('run-status-42-ok')));
      await tester.enterText(find.byKey(const Key('run-value-42')), '9');
      await tester.tap(find.byKey(const Key('run-status-43-ok')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('run-finish')));
      await tester.tap(find.byKey(const Key('run-finish')));
      await tester.pumpAndSettle();

      expect(find.text('Checkliste abgeschlossen'), findsOneWidget);
      // Der Server hat „in Ordnung“ wegen des Grenzwerts auf „nicht in Ordnung“ gesetzt.
      expect(
        find.textContaining(
          'Nicht in Ordnung · 9 °C · Messwert 9 °C außerhalb Grenzwert',
        ),
        findsOneWidget,
      );
      expect(find.text('Mangel #12 angelegt'), findsOneWidget);
      expect(find.byKey(const Key('run-open-defects')), findsOneWidget);
    },
  );

  testWidgets('Zwischenstand wird geladen und gespeichert', (tester) async {
    final api = _RunApi(
      draft: ChecklistDraft(
        id: 9,
        note: 'Bitte Heizung prüfen',
        results: const {
          42: ChecklistItemResult(status: 'ok', value: 5.2),
          43: ChecklistItemResult(status: 'na', reason: 'Plombe fehlt'),
        },
        updatedAt: DateTime.utc(2026, 11, 9, 6, 10),
        updatedBy: 'Alex Muster',
      ),
    );
    var popped = false;
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChecklistRunScreen(api: api, checklist: _checklist()),
                  ),
                );
                popped = result == true;
              },
              child: const Text('öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    expect(api.draftLoads, 1);
    expect(find.textContaining('Alex Muster geladen'), findsOneWidget);
    expect(find.text('5,2'), findsOneWidget);
    expect(find.text('Plombe fehlt'), findsOneWidget);
    expect(find.text('Bitte Heizung prüfen'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('run-save-draft')));
    await tester.tap(find.byKey(const Key('run-save-draft')));
    await tester.pumpAndSettle();

    expect(api.saved.single[43]?.reason, 'Plombe fehlt');
    expect(api.saved.single[42]?.valueText, '5,2');
    expect(api.notes.single, 'Bitte Heizung prüfen');
    expect(popped, isTrue);
  });

  testWidgets(
    'Liste: 0.28-Checkliste startet den Lauf, Zwischenstand sichtbar',
    (tester) async {
      final api = _RunApi(
        lists: [
          _checklist(
            draft: ChecklistDraft(
              id: 9,
              updatedAt: DateTime.utc(2026, 11, 9, 6, 10),
              updatedBy: 'Alex Muster',
            ),
          ),
        ],
      );
      await tester.pumpWidget(localizedApp(home: ChecklistenScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('2 Prüfpunkte'), findsOneWidget);
      expect(find.textContaining('Alex Muster'), findsOneWidget);
      expect(find.text('Zwischenstand fortsetzen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checklist-start-5')));
      await tester.pumpAndSettle();
      expect(find.byType(ChecklistRunScreen), findsOneWidget);
    },
  );
}
