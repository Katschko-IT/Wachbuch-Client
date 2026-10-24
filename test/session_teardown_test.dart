import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wachbuch_mobile/auth/session_store.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/main.dart';
import 'package:wachbuch_mobile/screens/login_screen.dart';
import 'package:wachbuch_mobile/screens/server_setup_screen.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';

class _MemorySessionStore extends SessionStore {
  _MemorySessionStore({this.url, this.token});

  String? url;
  String? token;
  DateTime? expiresAt;

  @override
  Future<String?> readServerUrl() async => url;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<DateTime?> readTokenExpiresAt() async => expiresAt;

  @override
  Future<void> writeServerUrl(String value) async => url = value;

  @override
  Future<void> writeToken(String value, {DateTime? expiresAt}) async {
    token = value;
    this.expiresAt = expiresAt;
  }

  @override
  Future<void> clearToken() async {
    token = null;
    expiresAt = null;
  }

  @override
  Future<void> clearAll() async {
    url = null;
    token = null;
    expiresAt = null;
  }

  @override
  Future<bool> isTokenExpired({DateTime? now}) async => false;
}

const _jwk = {'kty': 'EC', 'crv': 'P-256', 'd': 'geheim'};

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    CryptoSession.instance.lock();
  });

  testWidgets('Abmelden sperrt die entschlüsselte Chat-Identität', (tester) async {
    _usePhone(tester);
    final demo = DemoService.rettungsdienst;
    final store = _MemorySessionStore(
      url: demo.serverUrl,
      token: 'wb_demo_${demo.id}',
    );
    await tester.pumpWidget(WachbuchApp(store: store));
    await tester.binding.setLocale('de', '');
    await tester.pumpAndSettle();

    CryptoSession.instance.unlockWith(_jwk);
    expect(CryptoSession.instance.isUnlocked, isTrue);

    await tester.tap(find.text('Konto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();

    expect(CryptoSession.instance.isUnlocked, isFalse);
  });

  testWidgets('Serverwechsel sperrt die entschlüsselte Chat-Identität', (tester) async {
    _usePhone(tester);
    final store = _MemorySessionStore(url: 'https://wache.example.org');
    await tester.pumpWidget(WachbuchApp(store: store));
    await tester.binding.setLocale('de', '');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    CryptoSession.instance.unlockWith(_jwk);
    await tester.tap(find.byTooltip('Server ändern'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupScreen), findsOneWidget);
    expect(CryptoSession.instance.isUnlocked, isFalse);
  });
}
