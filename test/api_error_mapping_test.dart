import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';

const _nginxHtml = '<html><head><title>413 Request Entity Too Large</title>'
    '</head><body><center><h1>413 Request Entity Too Large</h1></center>'
    '<hr><center>nginx</center></body></html>';

WachbuchApi _api(http.Response response) => WachbuchApi(
      baseUrl: 'https://wache.example.org',
      token: 'wb_test',
      client: MockClient((_) async => response),
    );

Future<ApiException> _uploadError(http.Response response) async {
  try {
    await _api(response).uploadDefectAttachment(
      1,
      filename: 'foto.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
  } on ApiException catch (error) {
    return error;
  }
  fail('ApiException erwartet');
}

void main() {
  group('Antworten ohne JSON-Körper', () {
    test('413 von nginx wird zu „Datei zu groß“', () async {
      final error = await _uploadError(
        http.Response(_nginxHtml, 413, headers: {'content-type': 'text/html'}),
      );
      expect(error.statusCode, 413);
      // Ohne Zahl: die Proxy-Grenze gilt für den base64-kodierten Body.
      expect(error.message, 'Datei zu groß für den Server');
      expect(error.message, isNot(contains('MiB')));
    });

    test('415 ohne Körper wird zu „Dateityp nicht unterstützt“', () async {
      final error = await _uploadError(http.Response('', 415));
      expect(error.statusCode, 415);
      expect(error.message, 'Dateityp nicht unterstützt');
    });

    test('429 von nginx ohne Retry-After', () async {
      final error = await _uploadError(
        http.Response('<html>429 Too Many Requests</html>', 429),
      );
      expect(error.statusCode, 429);
      expect(error.message, 'Zu viele Anfragen – bitte kurz warten');
    });

    test('429 nennt die Wartezeit aus Retry-After', () async {
      final error = await _uploadError(
        http.Response('', 429, headers: {'retry-after': '30'}),
      );
      expect(
        error.message,
        'Zu viele Anfragen – bitte kurz warten (erneut versuchen in 30 s)',
      );
    });

    test('429 mit JSON-Körper behält die Servermeldung und ergänzt Retry-After',
        () async {
      final error = await _uploadError(
        http.Response(
          jsonEncode({
            'ok': false,
            'error': {'code': 'rate_limit', 'message': 'Zu viele Anfragen.'},
          }),
          429,
          headers: {'retry-after': '12'},
        ),
      );
      expect(error.code, 'rate_limit');
      expect(error.message, 'Zu viele Anfragen. (erneut versuchen in 12 s)');
    });

    test('413 mit JSON-Körper behält die Servermeldung', () async {
      final error = await _uploadError(
        http.Response(
          jsonEncode({
            'ok': false,
            'error': {
              'code': 'payload_too_large',
              'message': 'Anhang ist zu groß.',
            },
          }),
          413,
        ),
      );
      expect(error.message, 'Anhang ist zu groß.');
    });

    test('andere 4xx mit HTML bleiben „ungültige Antwort“', () async {
      final error = await _uploadError(http.Response('<html>teapot</html>', 418));
      expect(error.message, 'Der Server hat eine ungültige Antwort gesendet.');
    });
  });

  group('Fotogrenze ist überall 5 MiB', () {
    const limit = 5 * 1024 * 1024;

    test('eine Konstante wie MAX_ATTACHMENT_BYTES des Servers', () {
      expect(WachbuchApi.maxAttachmentBytes, limit);
      expect(WachbuchApi.exceedsAttachmentLimit(3 * 1024 * 1024), isFalse);
      expect(WachbuchApi.exceedsAttachmentLimit(limit), isFalse);
      expect(WachbuchApi.exceedsAttachmentLimit(limit + 1), isTrue);
    });

    test('5 MiB + 1 Byte scheitert vor dem Netz mit 413', () async {
      var calls = 0;
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 201);
        }),
      );

      await expectLater(
        api.uploadDefectAttachment(
          1,
          filename: 'gross.jpg',
          contentType: 'image/jpeg',
          bytes: Uint8List(limit + 1),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 413)),
      );
      expect(calls, 0);
    });

    test('genau 5 MiB werden gesendet', () async {
      var calls = 0;
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_test',
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({'id': 1, 'filename': 'a.jpg', 'content_type': 'image/jpeg'}),
            201,
          );
        }),
      );

      await api.uploadDefectAttachment(
        1,
        filename: 'a.jpg',
        contentType: 'image/jpeg',
        bytes: Uint8List(limit),
      );
      expect(calls, 1);
    });

    test('keine abweichende Fotogrenze im Quelltext', () {
      // Die alte Prüfung `bytes.length > 2 * 1024 * 1024` darf nicht
      // zurückkommen (12 MiB Gesamtgrenze der Demo zählt nicht).
      final twoMiB = RegExp(r'(?<!\d)2\s*\*\s*1024\s*\*\s*1024');
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (twoMiB.hasMatch(file.readAsStringSync())) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
