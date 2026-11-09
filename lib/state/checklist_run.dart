/// Hilfen für den Checklisten-Lauf (Server ab 0.28).
library;

import 'package:wachbuch_mobile/models/checkliste.dart';

/// Prüffehler des Servers, aufgeteilt nach Prüfpunkt.
class ChecklistErrorAssignment {
  const ChecklistErrorAssignment({
    this.byItem = const {},
    this.general = const [],
  });

  /// Meldungen je Server-Kennung des Prüfpunkts.
  final Map<int, List<String>> byItem;

  /// Meldungen ohne erkennbaren Prüfpunkt (z. B. „Ergebnisse fehlen“).
  final List<String> general;

  bool get isEmpty => byItem.isEmpty && general.isEmpty;
}

/// Ordnet die Meldungen aus `errors` (400 `validation_error`) den
/// Prüfpunkten zu.
///
/// Der Server nennt den Prüfpunkt in jeder Meldung mit seinem Text in
/// Anführungszeichen („…“, deutsche oder englische Typografie), z. B.
/// `Pflichtpunkt „Plombe intakt“ ist nicht ausgefüllt.` Gezählt wird nur
/// der vollständige Text zwischen den Anführungszeichen, nie ein Teilstring;
/// passt kein Prüfpunkt, bleibt die Meldung allgemein.
ChecklistErrorAssignment assignChecklistErrors(
  List<ChecklistItem> items,
  List<String> errors,
) {
  final byItem = <int, List<String>>{};
  final general = <String>[];
  for (final message in errors) {
    final quoted = _quotedTexts(message);
    ChecklistItem? match;
    for (final item in items) {
      final id = item.serverId;
      if (id == null || item.label.isEmpty) continue;
      if (quoted.contains(item.label)) {
        if (match == null || item.label.length > match.label.length) {
          match = item;
        }
      }
    }
    final id = match?.serverId;
    if (id == null) {
      general.add(message);
    } else {
      byItem.putIfAbsent(id, () => []).add(message);
    }
  }
  return ChecklistErrorAssignment(
    byItem: {
      for (final entry in byItem.entries)
        entry.key: List.unmodifiable(entry.value),
    },
    general: List.unmodifiable(general),
  );
}

const _quotePairs = {'„': '“', '“': '”', '"': '"', '«': '»', '»': '«'};

Set<String> _quotedTexts(String message) {
  final found = <String>{};
  for (final pair in _quotePairs.entries) {
    var start = message.indexOf(pair.key);
    while (start >= 0) {
      final end = message.indexOf(pair.value, start + pair.key.length);
      if (end < 0) break;
      found.add(message.substring(start + pair.key.length, end).trim());
      start = message.indexOf(pair.key, end + pair.value.length);
    }
  }
  return found;
}
