import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wachbuch_mobile/api/server_address.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';

/// Full-screen QR scanner for the Wachwerk server address.
///
/// Camera is only used for this setup step (Play User Data / Camera policy:
/// permission requested just-in-time with an on-screen purpose explanation).
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({
    super.key,
    this.accept,
    this.title,
    this.cameraHint,
    this.invalidMessage,
    this.footer,
  });

  /// Prüft den gelesenen Inhalt; Standard ist ein Wachwerk-Server-Link.
  final bool Function(String raw)? accept;
  final String? title;
  final String? cameraHint;
  final String? invalidMessage;
  final String? footer;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        // Nur prüfen; zurückgegeben wird der vollständige Inhalt, damit
        // Zertifikats-Fingerabdruck und Kopplungscode erhalten bleiben.
        final accept = widget.accept;
        if (accept == null) {
          parseServerLink(raw);
        } else if (!accept(raw.trim())) {
          throw ArgumentError('QR-Code passt nicht');
        }
        _handled = true;
        await _controller.stop();
        if (!mounted) return;
        Navigator.of(context).pop(raw.trim());
        return;
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _error =
              widget.invalidMessage ??
              AppLocalizations.of(context)!.qrScanInvalid,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.qrScanTitle)),
      body: Column(
        children: [
          Material(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.cameraHint ?? l.qrScanCameraHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(
                        WachbuchTokens.radiusLg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ErrorBanner(message: _error!),
            ),
          if (widget.footer?.isEmpty != true)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.footer ?? l.qrScanWebHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Explains camera use (Play policy) then requests permission and opens scanner.
Future<String?> openServerQrScanner(BuildContext context) =>
    openQrScanner(context);

/// Kamera-Hinweis, Berechtigung und Scanner; mit [accept] für andere
/// QR-Codes als den Server-Link (z. B. Fahrzeug- oder Geräteaufkleber).
Future<String?> openQrScanner(
  BuildContext context, {
  bool Function(String raw)? accept,
  String? purpose,
  String? title,
  String? invalidMessage,
  String? footer,
  String? deniedMessage,
}) async {
  final l = AppLocalizations.of(context)!;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.qrCameraDialogTitle),
      content: Text(purpose ?? l.qrCameraDialogMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.qrCameraContinue),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return null;

  final status = await Permission.camera.request();
  if (!context.mounted) return null;
  if (!status.isGranted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.qrCameraDeniedTitle),
        content: Text(deniedMessage ?? l.qrCameraDeniedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.qrCameraOk),
          ),
          if (status.isPermanentlyDenied)
            FilledButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(ctx);
              },
              child: Text(l.qrCameraSettings),
            ),
        ],
      ),
    );
    return null;
  }

  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => QrScanScreen(
        accept: accept,
        title: title,
        cameraHint: purpose,
        invalidMessage: invalidMessage,
        footer: footer,
      ),
    ),
  );
}
