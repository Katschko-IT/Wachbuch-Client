import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/screens/kaffeekasse_screen.dart';

import 'test_localization.dart';

Map<String, dynamic> _serverPayload() => {
      'ok': true,
      'balance_euros': -5.0,
      'scope': 'own',
      'results': [],
      'monthly_fee_euros': 5.0,
      'own': {
        'participant': true,
        'open_euros': 5.0,
        'credit_euros': 0.0,
        'months': [
          {'month': '2026-10', 'status': 'open', 'open_euros': 5.0},
          {'month': '2026-09', 'status': 'paid', 'open_euros': 0.0},
        ],
      },
      'payment': {
        'methods': ['cash', 'transfer', 'paypal'],
        'suggested_euros': 5.0,
        'iban': 'DE89370400440532013000',
        'bic': '',
        'account_holder': 'Kaffeekasse RW',
        'transfer_text': 'Kaffeekasse RW Nord Mara Muster',
        'paypal_me_url': 'https://paypal.me/kasse',
        'wero_link': 'javascript:alert(1)',
        'note': 'Bitte bis zum 10.',
      },
    };

void main() {
  test('parses own months and payment ways', () {
    final kasse = Kaffeekasse.fromJson(_serverPayload());
    expect(kasse.hasMonthlyFee, isTrue);
    expect(kasse.own!.formattedOpen, '5,00 €');
    expect(kasse.own!.months.first.month, DateTime(2026, 10));
    expect(kasse.own!.months.first.status, 'open');
    expect(kasse.payment!.methods, ['cash', 'transfer', 'paypal']);
    expect(kasse.payment!.formattedIban, 'DE89 3704 0044 0532 0130 00');
    expect(kasse.payment!.weroUrl, isEmpty, reason: 'nur https-Links');
    // Früher wurde `payment` als Text gelesen – jetzt kommt nur der Hinweis an.
    expect(kasse.paymentHint, 'Bitte bis zum 10.');
  });

  test('older servers without own/payment keep working', () {
    final kasse = Kaffeekasse.fromJson({'balance_euros': 3.5, 'results': [], 'payment_hint': 'Bar'});
    expect(kasse.hasMonthlyFee, isFalse);
    expect(kasse.payment, isNull);
    expect(kasse.paymentHint, 'Bar');
  });

  test('reportCoffeePayment posts once without retry', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, '/api/v1/kaffeekasse/bezahlt/');
      expect(jsonDecode(request.body), {'method': 'cash', 'amount_euros': '5.00', 'note': 'Oktober'});
      return http.Response(jsonEncode({'ok': false, 'error': 'down'}), 503);
    });
    final api = WachbuchApi(baseUrl: 'https://wache.example.org', token: 't', client: client);
    await expectLater(
      api.reportCoffeePayment(method: 'cash', amountEuros: 5, note: 'Oktober'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1, reason: 'eine doppelte Meldung wäre eine doppelte Buchung');
  });

  testWidgets('demo: tick off the open month', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = DemoWachbuchApi(profile: demoProfileFor(DemoService.rettungsdienst));
    await tester.pumpWidget(localizedApp(home: KaffeekasseScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Offen'), findsOneWidget);
    expect(find.text('5,00 €'), findsWidgets);
    expect(find.text('DE89 3704 0044 0532 0130 00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coffee-i-paid')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('coffee-pay-amount')), '0');
    await tester.tap(find.byKey(const Key('coffee-pay-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Bitte einen Betrag zwischen 0,01 und 500 € eingeben.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coffee-pay-amount')), '5,00');
    await tester.tap(find.byKey(const Key('coffee-pay-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Danke! Deine Zahlung ist eingetragen.'), findsOneWidget);
    expect(find.text('Alles bezahlt'), findsOneWidget);
  });
}
