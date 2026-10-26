import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/ui/handover_filter.dart';

class HandoverState extends ChangeNotifier {
  HandoverState({required this.api});

  final WachbuchApi api;

  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  ApiException? _lastError;
  String _searchQuery = '';
  final Set<String> _statuses = {};
  final Set<String> _priorities = {};
  bool _disposed = false;

  UnmodifiableListView<Map<String, dynamic>> get items =>
      UnmodifiableListView(_items);
  bool get loading => _loading;
  String? get error => _error;
  ApiException? get lastError => _lastError;
  String get searchQuery => _searchQuery;
  Set<String> get statuses => Set.unmodifiable(_statuses);
  Set<String> get priorities => Set.unmodifiable(_priorities);

  List<Map<String, dynamic>> get filteredItems => filterHandovers(
        _items,
        query: _searchQuery,
        statuses: _statuses,
        priorities: _priorities,
      );

  Future<void> reload() async {
    _loading = true;
    _error = null;
    _lastError = null;
    _notify();
    try {
      _items = await api.handovers();
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Legt eine Übergabe an und lädt die Liste neu. Fehler gehen an den Aufrufer.
  Future<Map<String, dynamic>> create({
    required String title,
    required String details,
    required String category,
    required String priority,
  }) async {
    final created = await api.createHandover(
      title: title,
      details: details,
      category: category,
      priority: priority,
    );
    await reload();
    return created;
  }

  /// Ändert den Status; erledigte Übergaben verschwinden wie auf dem Server
  /// aus der aktiven Liste.
  Future<Map<String, dynamic>> setStatus(int id, String status) async {
    final updated = await api.setHandoverStatus(id, status);
    if (status == 'done') {
      _items = [
        for (final item in _items)
          if (item['id'] != id) item,
      ];
    } else {
      _items = [
        for (final item in _items)
          if (item['id'] == id) {...item, ...updated, 'status': status} else item,
      ];
    }
    _notify();
    return updated;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void toggleStatus(String value, {required bool selected}) {
    selected ? _statuses.add(value) : _statuses.remove(value);
    _notify();
  }

  void togglePriority(String value, {required bool selected}) {
    selected ? _priorities.add(value) : _priorities.remove(value);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
