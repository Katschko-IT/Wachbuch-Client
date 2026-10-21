import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';

/// Regression tests built from payloads the Django server actually returns
/// (server 0.21.0). The previous suites used invented key names, which is why
/// these defects stayed green.
void main() {
  group('Kaffeekasse gegen echte Serverantwort', () {
    final payload = <String, dynamic>{
      'ok': true,
      'balance_euros': 42.5,
      'results': [
        {
          'id': 1,
          'member': {'id': 1, 'username': 'michael', 'display_name': 'Michael'},
          'amount_euros': -2.0,
          'reason': 'Kaffee',
          'created_at': '2026-08-02T10:00:00+00:00',
        },
      ],
    };

    test('liest Saldo aus balance_euros und formatiert das Währungssymbol', () {
      final kasse = Kaffeekasse.fromJson(payload);
      expect(kasse.balance, '42,50 €');
      expect(kasse.balance.contains('Closure'), isFalse,
          reason: 'Funktionsreferenz darf nicht interpoliert werden');
    });

    test('liest Buchungen aus results inklusive Betrag und Grund', () {
      final kasse = Kaffeekasse.fromJson(payload);
      expect(kasse.ledger, hasLength(1));
      final entry = kasse.ledger.single;
      expect(entry.amount, -2);
      expect(entry.description, 'Kaffee');
      expect(entry.userName, 'Michael');
      expect(entry.formattedAmount, '-2,00 €');
      expect(kasse.isNegative, isFalse);
    });

    test('behält die alten Schlüssel weiterhin', () {
      final kasse = Kaffeekasse.fromJson({
        'balance': '-3,50',
        'ledger': [
          {'id': 2, 'amount': '-3.50', 'description': 'Wasser'},
        ],
      });
      expect(kasse.balance, '-3,50 €');
      expect(kasse.ledger.single.description, 'Wasser');
      expect(kasse.isNegative, isTrue);
    });
  });

  group('Checklisten gegen echte Serverantwort', () {
    final listPayload = <String, dynamic>{
      'id': 1,
      'title': 'Audit-Checkliste',
      'description': 'Morgens erledigen',
      'items': ['Synthetischer Prüfpunkt A', 'Synthetischer Prüfpunkt B'],
      'last_completed_at': null,
      'last_completed_by': null,
      'interval': 'weekly',
      'due_next': '2026-10-28T11:00:00+00:00',
      'overdue': false,
    };

    test('übernimmt last_completed_at beim Neuladen der Liste', () {
      final liste = Checklist.fromJson({
        ...listPayload,
        'last_completed_at': '2026-10-21T11:00:46.665373+00:00',
      });
      expect(liste.completedAt, isNotNull);
      expect(liste.completedAt!.toUtc().hour, 11);
    });

    test('übernimmt Prüfpunkte, die der Server als Strings liefert', () {
      final liste = Checklist.fromJson(listPayload);
      expect(liste.items.map((item) => item.label),
          ['Synthetischer Prüfpunkt A', 'Synthetischer Prüfpunkt B']);
      expect(liste.title, 'Audit-Checkliste');
      expect(liste.description, 'Morgens erledigen');
    });

    test('Akzeptiert weiterhin Map-Prüfpunkte', () {
      final liste = Checklist.fromJson({
        ...listPayload,
        'items': [
          {'id': 9, 'label': 'Gerät prüfen', 'checked': true},
        ],
      });
      expect(liste.items.single.label, 'Gerät prüfen');
      expect(liste.items.single.checked, isTrue);
    });

    test('Abschlussantwort behält Zeitpunkt, Titel und Prüfpunkte', () {
      final completion = <String, dynamic>{
        'ok': true,
        'id': 4,
        'checklist': 1,
        'completed_by': {'id': 1, 'username': 'audit_lead'},
        'created_at': '2026-10-21T11:00:46.665373+00:00',
        'interval': 'weekly',
        'due_next': '2026-10-28T11:00:46.669156+00:00',
        'overdue': false,
      };
      final merged = Checklist.fromJson({
        ...completion,
        'completed': true,
        'completed_at': completion['completed_at'] ?? completion['created_at'],
      });
      expect(merged.completedAt, isNotNull);
      // Der Dialog/Die Liste ergänzt Titel und Punkte aus dem bekannten Eintrag.
      final original = Checklist.fromJson(listPayload);
      final shown = merged.copyWith(
        title: merged.title.isEmpty ? original.title : merged.title,
        description:
            merged.description.isEmpty ? original.description : merged.description,
        items: original.items,
      );
      expect(shown.title, 'Audit-Checkliste');
      expect(shown.description, 'Morgens erledigen');
      expect(shown.items, hasLength(2));
      expect(shown.completed, isTrue);
    });
  });
}
