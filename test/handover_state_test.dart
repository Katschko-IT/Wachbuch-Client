import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/state/handover_state.dart';

class _FakeApi extends WachbuchApi {
  _FakeApi(this._result)
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final Object _result;

  @override
  Future<List<Map<String, dynamic>>> handovers() async {
    if (_result is Exception) throw _result;
    return List<Map<String, dynamic>>.from(_result as List);
  }
}

void main() {
  test('reload() populates items and notifies listeners', () async {
    final api = _FakeApi([
      {'title': 'RTW', 'status': 'open', 'priority': 'urgent'},
    ]);
    final state = HandoverState(api: api);

    var notifications = 0;
    state.addListener(() => notifications++);

    expect(state.loading, isFalse);
    expect(state.items, isEmpty);

    final future = state.reload();
    expect(state.loading, isTrue);
    await future;

    expect(state.loading, isFalse);
    expect(state.error, isNull);
    expect(state.items.length, 1);
    expect(notifications, greaterThanOrEqualTo(2));
    state.dispose();
  });

  test('reload() stores error message and status on API failure', () async {
    final api = _FakeApi(ApiException(503, 'Nicht erreichbar'));
    final state = HandoverState(api: api);

    await state.reload();

    expect(state.loading, isFalse);
    expect(state.items, isEmpty);
    expect(state.error, contains('Nicht erreichbar'));
    expect(state.lastError?.statusCode, 503);
    state.dispose();
  });

  test('filteredItems combine search query, status and priority filters', () async {
    final api = _FakeApi([
      {'title': 'RTW auffüllen', 'status': 'open', 'priority': 'urgent'},
      {'title': 'Medikamente', 'status': 'in_progress', 'priority': 'normal'},
      {'title': 'Tor prüfen', 'status': 'done', 'priority': 'important'},
    ]);
    final state = HandoverState(api: api);
    await state.reload();

    expect(state.filteredItems.length, 3);

    state.setSearchQuery('medikament');
    expect(state.filteredItems.length, 1);
    expect(state.filteredItems.first['title'], 'Medikamente');

    state.setSearchQuery('');
    state.toggleStatus('open', selected: true);
    expect(state.filteredItems.length, 1);
    expect(state.filteredItems.first['title'], 'RTW auffüllen');

    state.toggleStatus('open', selected: false);
    state.togglePriority('urgent', selected: true);
    state.setSearchQuery('tor');
    expect(state.filteredItems, isEmpty);

    // filteredItemsFor with AppLocalizations resolves category, status and priority labels
    final l10n = lookupAppLocalizations(const Locale('de'));
    state.togglePriority('urgent', selected: false);
    state.setSearchQuery('fahrzeug'); // vehicle category in German
    final vehicleItems = state.filteredItemsFor(l10n);
    expect(vehicleItems, isEmpty); // None has vehicle category in this dataset

    state.setSearchQuery('dringend'); // urgent in German
    final urgentItems = state.filteredItemsFor(l10n);
    expect(urgentItems.length, 1);
    expect(urgentItems.first['title'], 'RTW auffüllen');

    state.dispose();
  });

  test('reload() then dispose keeps listeners safe from late completion', () async {
    final api = _FakeApi(ApiException(0, 'Netzwerkfehler'));
    final state = HandoverState(api: api);
    state.addListener(() {});
    await state.reload();
    state.dispose();
    expect(state.error, isNotNull);
  });
}
