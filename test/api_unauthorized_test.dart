import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';

/// Fehlerformen aus core/api/views.py (`api_token_required`).
http.Response _error(int status, String message, {String? code}) {
  return http.Response(
    jsonEncode({
      'ok': false,
      'error': {
        'code': code ?? (status == 401 ? 'auth_required' : 'forbidden'),
        'message': message,
        'correlation_id': 'c-1',
      },
    }),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('onUnauthorized', () {
    late List<ApiException> calls;

    WachbuchApi api(http.Response response, {String? token = 'wb_test'}) {
      return WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: token,
        client: MockClient((_) async => response),
        onUnauthorized: calls.add,
      );
    }

    setUp(() => calls = []);

    test('401 löst den Callback aus und wirft weiter', () async {
      final client = api(_error(401, 'Ungültiges oder widerrufenes API-Token.'));

      await expectLater(
        client.me(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(calls, hasLength(1));
      expect(calls.single.isNoActiveMembership, isFalse);
    });

    test('403 „Kein aktiver Wachenzugang“ löst den Callback aus', () async {
      final client = api(_error(403, 'Kein aktiver Wachenzugang.'));

      await expectLater(client.handovers(), throwsA(isA<ApiException>()));
      expect(calls, hasLength(1));
      expect(calls.single.isNoActiveMembership, isTrue);
    });

    test('andere 403 (Rolle/Scope) melden nicht ab', () async {
      final client = api(_error(403, 'Rolle darf den Status nicht ändern.'));

      await expectLater(client.handovers(), throwsA(isA<ApiException>()));
      expect(calls, isEmpty);
    });

    test('fehlgeschlagene Anmeldung ohne Token meldet nicht ab', () async {
      final client = api(_error(401, 'Anmeldung fehlgeschlagen.'), token: null);

      await expectLater(
        client.obtainToken(username: 'a', password: 'b'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, isEmpty);
    });

    test('401 bei Anhang-Download meldet ebenfalls ab', () async {
      final client = api(_error(401, 'Authentifizierung erforderlich.'));

      await expectLater(client.downloadAttachment(3), throwsA(isA<ApiException>()));
      expect(calls, hasLength(1));
    });

    test('copyWithToken übernimmt den Callback', () async {
      final client = api(_error(401, 'x'), token: null).copyWithToken('wb_neu');

      await expectLater(client.me(), throwsA(isA<ApiException>()));
      expect(calls, hasLength(1));
    });
  });
}
