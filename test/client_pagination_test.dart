import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';
import 'package:wachbuch_mobile/api/client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  final base = Uri.parse('https://wache.example.org');

  group('sameOriginPath', () {
    test('accepts relative paths matching prefix', () {
      expect(
        sameOriginPath(base, '/api/v1/handovers/'),
        '/api/v1/handovers/',
      );
      expect(
        sameOriginPath(base, '/api/v1/defects/?active=1&limit=20'),
        '/api/v1/defects/?active=1&limit=20',
      );
    });

    test('accepts absolute URLs on the same origin matching prefix', () {
      expect(
        sameOriginPath(base, 'https://wache.example.org/api/v1/handovers/?page=2'),
        '/api/v1/handovers/?page=2',
      );
      expect(
        sameOriginPath(base, '  https://wache.example.org/api/v1/items  '),
        '/api/v1/items',
      );
    });

    test('rejects foreign host', () {
      expect(
        sameOriginPath(base, 'https://evil.example.com/api/v1/handovers/'),
        isNull,
      );
      expect(
        sameOriginPath(base, 'https://subdomain.wache.example.org/api/v1/handovers/'),
        isNull,
      );
    });

    test('rejects protocol mismatch (http vs https)', () {
      expect(
        sameOriginPath(base, 'http://wache.example.org/api/v1/handovers/'),
        isNull,
      );
    });

    test('rejects port mismatch', () {
      expect(
        sameOriginPath(base, 'https://wache.example.org:8443/api/v1/handovers/'),
        isNull,
      );
    });

    test('rejects protocol-relative URLs', () {
      expect(
        sameOriginPath(base, '//evil.example.com/api/v1/handovers/'),
        isNull,
      );
    });

    test('rejects path that does not match prefix', () {
      expect(
        sameOriginPath(base, '/admin/settings/'),
        isNull,
      );
      expect(
        sameOriginPath(base, '/api/v2/handovers/'),
        isNull,
      );
      expect(
        sameOriginPath(base, '/api/v1/handovers/', prefix: '/api/v1/defects/'),
        isNull,
      );
    });

    test('rejects null, empty, non-string, or invalid inputs', () {
      expect(sameOriginPath(base, null), isNull);
      expect(sameOriginPath(base, ''), isNull);
      expect(sameOriginPath(base, '   '), isNull);
      expect(sameOriginPath(base, 12345), isNull);
      expect(sameOriginPath(base, ['/api/v1/']), isNull);
    });
  });

  group('nextPagePath helper', () {
    test('extracts next from Map or raw string', () {
      expect(
        nextPagePath(base, {'next': '/api/v1/handovers/?page=2'}),
        '/api/v1/handovers/?page=2',
      );
      expect(
        nextPagePath(base, '/api/v1/handovers/?page=3'),
        '/api/v1/handovers/?page=3',
      );
      expect(
        nextPagePath(base, {'next': 'https://evil.example.com/api/v1/x/'}),
        isNull,
      );
      expect(
        nextPagePath(base, {'next': null}),
        isNull,
      );
    });

    test('WachbuchApi.nextPagePath delegates to unified logic', () {
      final api = WachbuchApi(baseUrl: 'https://wache.example.org');
      expect(
        api.nextPagePath({'next': '/api/v1/defects/?offset=100'}),
        '/api/v1/defects/?offset=100',
      );
      expect(
        api.nextPagePath({'next': 'https://wache.example.org/api/v1/defects/?offset=100'}),
        '/api/v1/defects/?offset=100',
      );
      expect(
        api.nextPagePath({'next': 'https://evil.example.com/api/v1/x/'}),
        isNull,
      );
      expect(
        api.nextPagePath({'next': '/admin/'}),
        isNull,
      );
    });
  });

  group('WachbuchApi cache exposure and clearing', () {
    test('api.cache and helper methods allow reading and clearing cache', () async {
      const storage = FlutterSecureStorage();
      final cache = SecureApiCache.forSession(
        baseUrl: 'https://wache.example.org',
        token: 'wb_token',
        storage: storage,
      );
      final api = WachbuchApi(
        baseUrl: 'https://wache.example.org',
        token: 'wb_token',
        cache: cache,
      );

      expect(api.cache, same(cache));
      expect(api.apiCache, same(cache));
      expect(await api.lastCacheUpdate(), isNull);

      final now = DateTime.utc(2026, 11, 2, 11, 0);
      await cache.writeJson('me', OfflineCachePolicy.wrap({'station': 'Nord'}, now));
      expect(await api.lastCacheUpdate(), now);

      await api.clearOfflineCache();
      expect(await api.lastCacheUpdate(), isNull);
    });
  });
}
