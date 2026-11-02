import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/api_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('session namespaces isolate equal cache keys', () async {
    const storage = FlutterSecureStorage();
    final first = SecureApiCache.forSession(
      baseUrl: 'https://wache-a.example.org',
      token: 'wb_a',
      storage: storage,
    );
    final second = SecureApiCache.forSession(
      baseUrl: 'https://wache-b.example.org',
      token: 'wb_b',
      storage: storage,
    );

    await first.writeJson('me', {'station': 'A'});
    await second.writeJson('me', {'station': 'B'});

    expect((await first.readJson('me'))?['station'], 'A');
    expect((await second.readJson('me'))?['station'], 'B');
  });

  test('clear removes persisted namespace keys even in a fresh instance', () async {
    const storage = FlutterSecureStorage();
    final writer = SecureApiCache.forSession(
      baseUrl: 'https://wache.example.org',
      token: 'wb_same_token',
      storage: storage,
    );
    await writer.writeJson('me', {'station': 'Wache'});
    await writer.writeJson('defects', {'results': [1, 2]});

    // Simulate an app restart: the new cache instance has no in-memory key set.
    final afterRestart = SecureApiCache.forSession(
      baseUrl: 'https://wache.example.org',
      token: 'wb_same_token',
      storage: storage,
    );
    expect(await afterRestart.readJson('me'), isNotNull);

    await afterRestart.clear();

    expect(await afterRestart.readJson('me'), isNull);
    expect(await afterRestart.readJson('defects'), isNull);
  });

  test('clearing one session does not delete another session cache', () async {
    const storage = FlutterSecureStorage();
    final first = SecureApiCache.forSession(
      baseUrl: 'https://wache.example.org',
      token: 'wb_first',
      storage: storage,
    );
    final second = SecureApiCache.forSession(
      baseUrl: 'https://wache.example.org',
      token: 'wb_second',
      storage: storage,
    );
    await first.writeJson('me', {'session': 'first'});
    await second.writeJson('me', {'session': 'second'});

    await first.clear();

    expect(await first.readJson('me'), isNull);
    expect((await second.readJson('me'))?['session'], 'second');
  });

  group('lastUpdatedAt und clear', () {
    test('lastUpdatedAt returns null when cache is empty', () async {
      const storage = FlutterSecureStorage();
      final cache = OfflineApiCache.forSession(
        baseUrl: 'https://wache.example.org',
        token: 'wb_token',
        storage: storage,
      );

      expect(await cache.lastUpdatedAt(), isNull);
      expect(await cache.oldestOrLatestTimestamp(), isNull);
    });

    test('lastUpdatedAt returns most recent cached_at timestamp', () async {
      const storage = FlutterSecureStorage();
      final cache = SecureApiCache.forSession(
        baseUrl: 'https://wache.example.org',
        token: 'wb_token',
        storage: storage,
      );

      final earlier = DateTime.utc(2026, 11, 2, 10, 0);
      final later = DateTime.utc(2026, 11, 2, 10, 30);

      await cache.writeJson('me', OfflineCachePolicy.wrap({'station': 'Nord'}, earlier));
      expect(await cache.lastUpdatedAt(), earlier);

      await cache.writeJson('handovers', {
        'cached_at': later.toIso8601String(),
        'results': <dynamic>[],
      });
      expect(await cache.lastUpdatedAt(), later);
      expect(await cache.oldestOrLatestTimestamp(), later);
    });

    test('clear removes all entries and resets lastUpdatedAt to null', () async {
      const storage = FlutterSecureStorage();
      final cache = OfflineApiCache.forSession(
        baseUrl: 'https://wache.example.org',
        token: 'wb_token',
        storage: storage,
      );

      final now = DateTime.utc(2026, 11, 2, 12, 0);
      await cache.writeJson('me', OfflineCachePolicy.wrap({'station': 'Nord'}, now));
      expect(await cache.lastUpdatedAt(), now);

      await cache.clear();
      expect(await cache.lastUpdatedAt(), isNull);
      expect(await cache.readJson('me'), isNull);
    });
  });

  group('formatOfflineCacheStatus', () {
    test('formats null as Keine Offline-Daten gespeichert', () {
      expect(
        formatOfflineCacheStatus(null, isGerman: true),
        'Keine Offline-Daten gespeichert',
      );
      expect(
        formatOfflineCacheStatus(null, isGerman: false),
        'No offline data stored',
      );
    });

    test('formats recent timestamp in minutes', () {
      final now = DateTime(2026, 11, 2, 14, 30);
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));

      expect(
        formatOfflineCacheStatus(fiveMinAgo, now: now, isGerman: true),
        'Zwischengespeicherte Offline-Daten (Stand: vor 5 Min.)',
      );
      expect(
        formatOfflineCacheStatus(fiveMinAgo, now: now, isGerman: false),
        'Cached offline data (as of: 5 min ago)',
      );
    });

    test('formats older timestamp on same day with time', () {
      final now = DateTime(2026, 11, 2, 14, 30);
      final twoHoursAgo = DateTime(2026, 11, 2, 12, 15);

      expect(
        formatOfflineCacheStatus(twoHoursAgo, now: now, isGerman: true),
        'Zwischengespeicherte Offline-Daten (Stand: 12:15 Uhr)',
      );
      expect(
        formatOfflineCacheStatus(twoHoursAgo, now: now, isGerman: false),
        'Cached offline data (as of: 12:15)',
      );
    });
  });
}
