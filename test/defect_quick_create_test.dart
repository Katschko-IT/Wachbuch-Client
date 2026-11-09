import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/assets_screen.dart';
import 'package:wachbuch_mobile/screens/defect_create_sheet.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/services/defect_photo.dart';

import 'test_localization.dart';

const _rtw = StationAsset(id: 'rtw-1', label: 'RTW 1', kind: 'vehicle');
const _defi = StationAsset(id: 'defi-2', label: 'Defi 2', kind: 'device');

final _photo = PickedPhoto(
  filename: 'mangel.jpg',
  contentType: 'image/jpeg',
  bytes: Uint8List.fromList(List.filled(2048, 1)),
);

class _DefectApi extends WachbuchApi {
  _DefectApi({this.version = '0.28.0', this.uploadError})
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final String? version;
  final ApiException? uploadError;
  final references = <String>[];
  final created = <Map<String, Object?>>[];
  final uploads = <String>[];

  @override
  Future<Map<String, dynamic>> discover() async => {
    'ok': true,
    'api_version': 'v1',
    'app_version': ?version,
  };

  @override
  Future<List<StationAsset>> assets() async => const [_rtw, _defi];

  @override
  Future<List<InventoryItem>> inventory() async => const [];

  @override
  Future<DefectPage> defectsForReference(
    String reference, {
    int limit = 5,
  }) async {
    references.add(reference);
    if (reference == 'rtw-1') {
      return const DefectPage(
        items: [Defect(id: 3, title: 'Trage klemmt', assetRef: 'RTW 1')],
        count: 2,
      );
    }
    return const DefectPage(items: [], count: 0);
  }

  @override
  Future<Defect> createDefect({
    required String title,
    String description = '',
    String assetRef = '',
    String priority = 'normal',
    String category = 'task',
    String? owner,
    DateTime? dueAt,
  }) async {
    created.add({
      'title': title,
      'asset_ref': assetRef,
      'priority': priority,
      'category': category,
    });
    return Defect(id: 91, title: title, assetRef: assetRef, category: category);
  }

  @override
  Future<DefectAttachment> uploadDefectAttachment(
    int defectId, {
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    uploads.add('$defectId:$filename:$contentType:${bytes.length}');
    return DefectAttachment.fromJson({
      'id': 1,
      'defect_id': defectId,
      'filename': filename,
    });
  }

  @override
  Future<DefectPage> defectsPage({
    bool includeDone = false,
    int limit = 100,
  }) async => const DefectPage(items: [], count: 0);

  @override
  Future<Map<String, dynamic>> me() async => {
    'membership': {'role': 'member'},
  };
}

Future<DefectReport?> _openSheet(
  WidgetTester tester,
  WachbuchApi api, {
  StationAsset? preselected,
  bool cameraFirst = false,
  DefectPhotoPicker? picker,
  Future<String?> Function(BuildContext context)? qrReader,
  required List<DefectReport?> results,
}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              results.add(
                await showDefectReportSheet(
                  context,
                  api: api,
                  preselected: preselected,
                  cameraFirst: cameraFirst,
                  photoPicker: picker ?? (_) async => null,
                  qrReader: qrReader,
                ),
              );
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
  return null;
}

void main() {
  group('Hilfen', () {
    test(
      'assetIdFromQr liest Fahrzeug-, Geräte- und Formular-Links desselben Servers',
      () {
        const base = 'https://wache.example.org';
        expect(
          assetIdFromQr('https://wache.example.org/fuhrpark/v/rtw-1/', base),
          'rtw-1',
        );
        expect(
          assetIdFromQr('https://wache.example.org/mpg/d/defi-2/', base),
          'defi-2',
        );
        expect(
          assetIdFromQr(
            'https://wache.example.org/maengel/neu/?asset=vehicle%3A3',
            base,
          ),
          'vehicle:3',
        );
        expect(
          assetIdFromQr('https://fremd.example.org/fuhrpark/v/rtw-1/', base),
          isNull,
        );
        expect(
          assetIdFromQr(
            'wachbuch://connect?url=https://wache.example.org',
            base,
          ),
          isNull,
        );
        expect(
          assetIdFromQr('https://wache.example.org/fuhrpark/', base),
          isNull,
        );
      },
    );

    test('Kategorie folgt dem Bezug wie im Web, ohne Bezug Material', () {
      expect(defaultCategoryFor(_rtw), 'vehicle');
      expect(defaultCategoryFor(_defi), 'device');
      expect(
        defaultCategoryFor(
          const StationAsset(id: 'k', label: 'K', kind: 'key'),
        ),
        'key',
      );
      expect(defaultCategoryFor(null), 'material');
    });

    test('ServerInfo: Funktionen von 1.2 erst ab 0.28.0', () {
      expect(
        ServerInfo.fromDiscovery({
          'app_version': '0.28.0',
        }).supportsDefectReferenceFilter,
        isTrue,
      );
      expect(
        ServerInfo.fromDiscovery({
          'app_version': '0.29.1-dev',
        }).supportsDefectReferenceFilter,
        isTrue,
      );
      expect(
        ServerInfo.fromDiscovery({
          'app_version': '0.27.0',
        }).supportsDefectReferenceFilter,
        isFalse,
      );
      expect(
        ServerInfo.fromDiscovery({}).supportsDefectReferenceFilter,
        isFalse,
      );
    });

    test('submitDefectReport legt an und lädt das Foto danach hoch', () async {
      final api = _DefectApi();
      final outcome = await submitDefectReport(
        api,
        DefectReport(
          title: 'Fahrzeug: RTW 1',
          assetRef: 'RTW 1',
          category: 'vehicle',
          photo: _photo,
        ),
      );
      expect(outcome.created, isTrue);
      expect(outcome.photoError, isNull);
      expect(api.uploads, ['91:mangel.jpg:image/jpeg:2048']);
    });

    test('scheitert nur das Foto, bleibt der Mangel bestehen', () async {
      final api = _DefectApi(
        uploadError: ApiException(413, 'Datei zu groß für den Server'),
      );
      final outcome = await submitDefectReport(
        api,
        DefectReport(title: 'Material: ohne Bezug', photo: _photo),
      );
      expect(outcome.created, isTrue);
      expect(outcome.photoError, 'Datei zu groß für den Server');
    });
  });

  testWidgets('Fotos über 5 MiB werden vor dem Upload verkleinert', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Rauschen lässt sich kaum komprimieren: das PNG ist deutlich größer
      // als die hier gesetzte Grenze.
      const size = 700;
      final random = Random(7);
      final pixels = Uint8List.fromList(
        List.generate(
          size * size * 4,
          (i) => i % 4 == 3 ? 255 : random.nextInt(256),
        ),
      );
      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: size,
        height: size,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = png!.buffer.asUint8List();
      const limit = 800 * 1024;
      expect(bytes.length, greaterThan(limit));

      final result = await ensureUploadable(
        PickedPhoto(
          filename: 'gross.jpg',
          contentType: 'image/jpeg',
          bytes: bytes,
        ),
        maxBytes: limit,
      );
      expect(result.downscaled, isTrue);
      expect(result.bytes.length, lessThanOrEqualTo(limit));
      expect(result.contentType, 'image/png');
      expect(result.filename, 'gross.png');

      final small = PickedPhoto(
        filename: 'klein.jpg',
        contentType: 'image/jpeg',
        bytes: Uint8List(10),
      );
      expect(
        identical(await ensureUploadable(small, maxBytes: limit), small),
        isTrue,
      );
    });
  });

  testWidgets('Kamera zuerst, Bezug vorgewählt: drei Tipps bis zum Speichern', (
    tester,
  ) async {
    final api = _DefectApi();
    final results = <DefectReport?>[];
    var cameraCalls = 0;
    await _openSheet(
      tester,
      api,
      preselected: _rtw,
      cameraFirst: true,
      picker: (source) async {
        if (source == ImageSource.camera) cameraCalls++;
        return _photo;
      },
      results: results,
    );

    expect(cameraCalls, 1);
    expect(find.byKey(const Key('defect-photo-preview')), findsOneWidget);
    // Kategorie aus dem Bezug, Priorität normal.
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('defect-category-vehicle')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('defect-priority-normal')))
          .selected,
      isTrue,
    );
    // Hinweis „bereits gemeldet“ über den exakten ?asset=-Filter.
    expect(api.references, ['rtw-1']);
    expect(find.byKey(const Key('defect-duplicates')), findsOneWidget);
    expect(find.text('Bereits gemeldet'), findsOneWidget);
    expect(find.text('• Trage klemmt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('defect-submit')));
    await tester.pumpAndSettle();

    final report = results.single!;
    expect(report.title, 'Fahrzeug: RTW 1');
    expect(report.assetRef, 'RTW 1');
    expect(report.category, 'vehicle');
    expect(report.priority, 'normal');
    expect(report.photo, same(_photo));
  });

  testWidgets('älterer Server: kein Hinweis „bereits gemeldet“', (
    tester,
  ) async {
    final api = _DefectApi(version: '0.27.0');
    await _openSheet(tester, api, preselected: _rtw, results: []);
    expect(api.references, isEmpty);
    expect(find.byKey(const Key('defect-duplicates')), findsNothing);
  });

  testWidgets(
    'ohne Inhalt wird nicht gemeldet; Chips ändern Kategorie und Priorität',
    (tester) async {
      final api = _DefectApi();
      final results = <DefectReport?>[];
      await _openSheet(tester, api, results: results);

      await tester.tap(find.byKey(const Key('defect-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Bitte ein Foto, einen Bezug, einen Titel oder eine Beschreibung angeben.',
        ),
        findsOneWidget,
      );
      expect(results, isEmpty);

      await tester.tap(find.byKey(const Key('defect-category-safety')));
      await tester.tap(find.byKey(const Key('defect-priority-urgent')));
      await tester.enterText(
        find.byKey(const Key('defect-description')),
        'Notausgang klemmt',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('defect-submit')));
      await tester.pumpAndSettle();

      final report = results.single!;
      expect(report.title, 'Sicherheit: ohne Bezug');
      expect(report.category, 'safety');
      expect(report.priority, 'urgent');
      expect(report.description, 'Notausgang klemmt');
    },
  );

  testWidgets('QR-Code am Gerät wählt den Bezug vor', (tester) async {
    final api = _DefectApi();
    final results = <DefectReport?>[];
    await _openSheet(
      tester,
      api,
      qrReader: (_) async => 'https://wache.example.org/mpg/d/defi-2/',
      results: results,
    );

    await tester.tap(find.byKey(const Key('defect-reference-qr')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('defect-category-device')))
          .selected,
      isTrue,
    );
    expect(api.references, contains('defi-2'));

    await tester.tap(find.byKey(const Key('defect-submit')));
    await tester.pumpAndSettle();
    expect(results.single!.assetRef, 'Defi 2');
    expect(results.single!.title, 'Gerät: Defi 2');
  });

  testWidgets(
    'Mängelliste: „Mangel mit Foto“ öffnet die Kamera und speichert',
    (tester) async {
      final api = _DefectApi();
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        localizedApp(
          home: DefectsScreen(
            api: api,
            role: 'member',
            photoPicker: (_) async => _photo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('defects-report-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('defect-photo-preview')), findsOneWidget);

      await tester.tap(find.byKey(const Key('defect-reference')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RTW 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('defect-submit')));
      await tester.pumpAndSettle();

      expect(api.created.single, {
        'title': 'Fahrzeug: RTW 1',
        'asset_ref': 'RTW 1',
        'priority': 'normal',
        'category': 'vehicle',
      });
      expect(api.uploads.single, startsWith('91:mangel.jpg'));
      expect(find.text('Mangel mit Foto angelegt.'), findsOneWidget);
    },
  );

  testWidgets('Geräte & Fahrzeuge: „Mangel melden“ nur für Inhaltsrollen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        home: AssetsScreen(api: _DefectApi(), role: 'member', username: 'alex'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-report-defect-rtw-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('asset-report-defect-rtw-1')));
    await tester.pumpAndSettle();
    expect(find.text('Mangel melden'), findsWidgets);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('defect-category-vehicle')))
          .selected,
      isTrue,
    );

    await tester.pumpWidget(
      localizedApp(
        home: AssetsScreen(
          key: const ValueKey('auditor'),
          api: _DefectApi(),
          role: 'auditor',
          username: 'pruef',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-report-defect-rtw-1')), findsNothing);
  });
}
