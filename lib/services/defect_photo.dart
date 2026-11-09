/// Mängelfotos aufnehmen, prüfen und vor dem Versand verkleinern.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wachbuch_mobile/api/client.dart';

/// Ein Foto, das so an `POST /api/v1/defects/{id}/attachments/` gehen kann.
class PickedPhoto {
  const PickedPhoto({
    required this.filename,
    required this.contentType,
    required this.bytes,
    this.downscaled = false,
  });

  final String filename;

  /// `image/jpeg`, `image/png` oder `image/webp` (wie der Server erlaubt).
  final String contentType;
  final Uint8List bytes;

  /// Die App hat das Bild verkleinert, weil es über der Grenze lag.
  final bool downscaled;

  String get sizeLabel {
    final kib = bytes.length / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(0)} KiB';
    return '${(kib / 1024).toStringAsFixed(1)} MiB';
  }
}

/// Grund, warum kein Foto übernommen wurde.
enum PhotoProblem { unsupportedType, tooLarge, unavailable }

class PhotoPickException implements Exception {
  const PhotoPickException(this.problem);

  final PhotoProblem problem;

  @override
  String toString() => 'PhotoPickException($problem)';
}

/// Foto aus Kamera oder Mediathek; `null`, wenn abgebrochen. In Tests
/// ersetzbar.
typedef DefectPhotoPicker = Future<PickedPhoto?> Function(ImageSource source);

/// Standard: `image_picker` mit 1600 px Kantenlänge und JPEG-Qualität 80,
/// danach [ensureUploadable].
Future<PickedPhoto?> pickDefectPhoto(ImageSource source) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
  } on PlatformException {
    throw const PhotoPickException(PhotoProblem.unavailable);
  }
  if (file == null) return null;
  final contentType = photoContentType(file.name, file.mimeType);
  if (contentType == null) {
    throw const PhotoPickException(PhotoProblem.unsupportedType);
  }
  final photo = PickedPhoto(
    filename: file.name,
    contentType: contentType,
    bytes: await file.readAsBytes(),
  );
  return ensureUploadable(photo);
}

/// Bildtyp aus MIME-Angabe oder Dateiendung; `null` für alles, was der
/// Server nicht annimmt.
String? photoContentType(String filename, String? mimeType) {
  final provided = mimeType?.toLowerCase();
  if (provided == 'image/jpeg' ||
      provided == 'image/png' ||
      provided == 'image/webp') {
    return provided;
  }
  final name = filename.toLowerCase();
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  return null;
}

/// Hält die 5-MiB-Grenze des Servers ein ([WachbuchApi.maxAttachmentBytes]).
///
/// Ein größeres Bild wird schrittweise verkleinert (Kantenlänge −25 % je
/// Schritt) und als PNG neu geschrieben; der Server schreibt es ohnehin als
/// JPEG ohne Metadaten neu. Gelingt das nicht, gibt es [PhotoProblem.tooLarge].
Future<PickedPhoto> ensureUploadable(
  PickedPhoto photo, {
  int maxBytes = WachbuchApi.maxAttachmentBytes,
}) async {
  if (photo.bytes.length <= maxBytes) return photo;
  final smaller = await downscaleImage(photo.bytes, maxBytes: maxBytes);
  if (smaller == null) throw const PhotoPickException(PhotoProblem.tooLarge);
  final dot = photo.filename.lastIndexOf('.');
  final base = dot > 0 ? photo.filename.substring(0, dot) : photo.filename;
  return PickedPhoto(
    filename: '${base.isEmpty ? 'foto' : base}.png',
    contentType: 'image/png',
    bytes: smaller,
    downscaled: true,
  );
}

/// Verkleinert [bytes] so lange, bis das PNG höchstens [maxBytes] groß ist.
/// `null`, wenn das Bild nicht lesbar ist oder auch bei [minEdge] Pixeln
/// Kantenlänge noch zu groß bleibt.
Future<Uint8List?> downscaleImage(
  Uint8List bytes, {
  required int maxBytes,
  int startEdge = 1600,
  int minEdge = 320,
}) async {
  final int width;
  final int height;
  try {
    final probe = await ui.instantiateImageCodec(bytes);
    final frame = await probe.getNextFrame();
    width = frame.image.width;
    height = frame.image.height;
    frame.image.dispose();
    probe.dispose();
  } catch (_) {
    return null;
  }
  var edge = width > height ? width : height;
  if (edge > startEdge) edge = startEdge;
  while (edge >= minEdge) {
    final landscape = width >= height;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: landscape ? edge : null,
      targetHeight: landscape ? null : edge,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data != null && data.lengthInBytes <= maxBytes) {
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    edge = (edge * 0.75).floor();
  }
  return null;
}
