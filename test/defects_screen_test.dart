import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';
import 'package:wachbuch_mobile/theme/high_contrast_theme.dart';

import 'test_localization.dart';

/// Antwortformen von core/api/wachalltag.py (Mängel und Anhänge).
class _DefectsApi extends WachbuchApi {
  _DefectsApi({this.attachments = const []})
      : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  List<DefectAttachment> attachments;
  Uint8List bytes = Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);

  @override
  Future<DefectPage> defectsPage({bool includeDone = false, int limit = 100}) async =>
      const DefectPage(
        items: [Defect(id: 1, title: 'Trage quietscht', priority: 'normal')],
        count: 1,
      );

  @override
  Future<List<DefectAttachment>> defectAttachments(int defectId) async =>
      attachments;

  @override
  Future<Uint8List> downloadAttachment(int id) async => bytes;
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openFirstAttachment(WidgetTester tester, WachbuchApi api) async {
  await tester.pumpWidget(localizedApp(home: DefectsScreen(api: api)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Trage quietscht'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PDF-Anhang zeigt Hinweis statt Bildvorschau', (tester) async {
    _usePhone(tester);
    final api = _DefectsApi(
      attachments: const [
        DefectAttachment(
          id: 5,
          defectId: 1,
          filename: 'pruefprotokoll.pdf',
          contentType: 'application/pdf',
          size: 2048,
        ),
      ],
    );
    await _openFirstAttachment(tester, api);

    await tester.tap(find.text('pruefprotokoll.pdf'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.text('Vorschau nicht verfügbar'), findsOneWidget);
    expect(
      find.text('pruefprotokoll.pdf (application/pdf)'),
      findsOneWidget,
    );
  });

  testWidgets('Bildanhang wird mit Fehler-Fallback gerendert', (tester) async {
    _usePhone(tester);
    final api = _DefectsApi(
      attachments: const [
        DefectAttachment(
          id: 6,
          defectId: 1,
          filename: 'trage.jpg',
          contentType: 'image/jpeg',
          size: 4096,
        ),
      ],
    );
    await _openFirstAttachment(tester, api);

    await tester.tap(find.text('trage.jpg'));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);
    final fallback = image.errorBuilder!(
      tester.element(find.byType(Image)),
      Exception('kaputt'),
      null,
    );
    await tester.pumpWidget(localizedApp(home: Scaffold(body: fallback)));
    expect(find.text('Vorschau nicht verfügbar'), findsWidgets);
    expect(find.text('trage.jpg (image/jpeg)'), findsWidgets);
  });

  // Gefunden im Ende-zu-Ende-Test auf dem iOS-Simulator: Das App-Theme gibt
  // FilledButton eine Mindestbreite „unendlich“ (Size.fromHeight); der
  // Foto-Button in der Zeile der Mängeldetails warf dadurch beim Layout
  // „BoxConstraints forces an infinite width“.
  for (final entry in {
    'hell': buildWachbuchTheme(Brightness.light),
    'dunkel': buildWachbuchTheme(Brightness.dark),
    'hoher Kontrast': HighContrastTheme.light(),
  }.entries) {
    testWidgets('Mängeldetails rendern mit App-Theme (${entry.key})',
        (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        localizedApp(
          theme: entry.value,
          home: DefectsScreen(api: _DefectsApi()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trage quietscht'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Foto hinzufügen'), findsOneWidget);
    });
  }
}
