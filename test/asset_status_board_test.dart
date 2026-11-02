import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/ui/asset_status_board.dart';

import 'test_localization.dart';

void main() {
  testWidgets('unbekannter Status zeigt „Status unbekannt“, nie „Einsatzklar“',
      (tester) async {
    final asset = StationAsset.fromJson({
      'id': 'rtw-2',
      'label': 'RTW 2',
      'kind': 'vehicle',
      'status': 'quarantine',
    });
    await tester.pumpWidget(
      localizedApp(home: Scaffold(body: AssetStatusBoard(assets: [asset]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('RTW 2'), findsOneWidget);
    expect(find.text('Status unbekannt'), findsOneWidget);
    expect(find.text('Einsatzklar'), findsNothing);
    expect(find.text('Außer Betrieb'), findsNothing);
    expect(find.text('Außer Dienst'), findsNothing);
  });

  testWidgets('bekannte Zustände behalten ihre Bezeichnung', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: const Scaffold(
          body: AssetStatusBoard(
            assets: [
              StationAsset(id: 'a', label: 'RTW 1', status: 'ready'),
              StationAsset(id: 'b', label: 'HLF 20', status: 'oob'),
              StationAsset(id: 'c', label: 'KTW 1', status: 'disinfection'),
              StationAsset(id: 'd', label: 'NEF 1', status: 'out_of_service'),
              StationAsset(id: 'e', label: 'GW 1', status: 'limited'),
              StationAsset(id: 'f', label: 'DLK 1', status: 'workshop'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einsatzklar'), findsOneWidget);
    expect(find.text('Außer Betrieb'), findsOneWidget);
    expect(find.text('Desinfektion'), findsOneWidget);
    expect(find.text('Außer Dienst'), findsOneWidget);
    expect(find.text('Eingeschränkt'), findsOneWidget);
    expect(find.text('Werkstatt'), findsOneWidget);
    expect(find.text('Status unbekannt'), findsNothing);
  });
}
