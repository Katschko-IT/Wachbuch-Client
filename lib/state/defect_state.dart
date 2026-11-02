import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';

/// Loads and mutates station defects (Mängel).
class DefectState extends ChangeNotifier {
  DefectState({required this.api});

  final WachbuchApi api;

  List<Defect> _items = const [];
  bool _loading = false;
  String? _error;
  ApiException? _lastError;
  bool _disposed = false;
  bool _showDone = false;
  bool _loadingMore = false;
  String? _next;
  int _totalCount = 0;

  List<Defect> get items => _items;

  /// Erledigte Mängel mitladen (sonst `active=1`).
  bool get showDone => _showDone;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _next != null && _next!.isNotEmpty;

  /// Gesamtzahl laut Server (`count`), auch wenn nur eine Seite geladen ist.
  int get totalCount => _totalCount;
  bool get loading => _loading;
  String? get error => _error;
  ApiException? get lastError => _lastError;
  bool get hasData => _items.isNotEmpty;

  int get openCount => _items.where((item) => item.isOpen).length;
  int get urgentCount => _items.where((item) => item.isUrgent).length;

  Future<void> reload() async {
    _loading = true;
    _error = null;
    _lastError = null;
    _notify();
    try {
      final page = await api.defectsPage(includeDone: _showDone);
      _items = page.items;
      _next = page.next;
      _totalCount = page.count;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      if (WachbuchApi.isModuleUnavailable(error)) {
        _items = const [];
        _next = null;
        _totalCount = 0;
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Nächste Seite über `next` laden und anhängen.
  Future<void> loadMore() async {
    final next = _next;
    if (next == null || next.isEmpty || _loadingMore) return;
    _loadingMore = true;
    _error = null;
    _lastError = null;
    _notify();
    try {
      final page = await api.defectsNext(next);
      final known = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...page.items.where((item) => !known.contains(item.id)),
      ];
      _next = page.next;
      _totalCount = page.count;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  /// Option „Erledigte anzeigen“; lädt die Liste neu.
  Future<void> setShowDone(bool value) async {
    if (value == _showDone) return;
    _showDone = value;
    await reload();
  }

  Future<Defect?> create({
    required String title,
    String description = '',
    String assetRef = '',
    String priority = 'normal',
    String category = 'task',
    DateTime? dueAt,
  }) async {
    _error = null;
    _lastError = null;
    try {
      final created = await api.createDefect(
        title: title,
        description: description,
        assetRef: assetRef,
        priority: priority,
        category: category,
        dueAt: dueAt,
      );
      _items = [created, ..._items];
      _totalCount++;
      _notify();
      return created;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return null;
    } catch (error) {
      _error = error.toString();
      _notify();
      return null;
    }
  }

  /// Beschreibung, Bezug, Priorität oder Frist ändern; null bei Fehler (siehe [error]).
  Future<Defect?> update(
    int id, {
    String? description,
    String? assetRef,
    String? priority,
    DateTime? dueAt,
    bool clearDue = false,
  }) async {
    _error = null;
    _lastError = null;
    try {
      final updated = await api.updateDefect(
        id,
        description: description,
        assetRef: assetRef,
        priority: priority,
        dueAt: dueAt,
        clearDue: clearDue,
      );
      _items = [
        for (final item in _items)
          if (item.id == id) updated else item,
      ];
      _notify();
      return updated;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return null;
    } catch (error) {
      _error = error.toString();
      _notify();
      return null;
    }
  }

  Future<bool> setStatus(int id, String status) async {
    _error = null;
    _lastError = null;
    try {
      final updated = await api.updateDefectStatus(id, status);
      _items = [
        for (final item in _items)
          if (item.id == id) updated else item,
      ];
      _notify();
      return true;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return false;
    } catch (error) {
      _error = error.toString();
      _notify();
      return false;
    }
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
