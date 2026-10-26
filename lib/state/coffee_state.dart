import 'package:flutter/foundation.dart';
import '../api/client.dart';
import '../models/kaffeekasse.dart';

class CoffeeState extends ChangeNotifier {
  CoffeeState({required this.api});

  final WachbuchApi api;

  Kaffeekasse? _data;
  bool _loading = false;
  String? _error;

  Kaffeekasse? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  /// „Ich habe bezahlt“ melden und danach neu laden. Fehler gehen an den Aufrufer.
  Future<void> reportPayment({
    required String method,
    required num amountEuros,
    String note = '',
  }) async {
    await api.reportCoffeePayment(method: method, amountEuros: amountEuros, note: note);
    await reload();
  }

  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await api.kaffeekasse();
    } catch (e) {
      _error = 'Kaffeekasse nicht erreichbar: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
