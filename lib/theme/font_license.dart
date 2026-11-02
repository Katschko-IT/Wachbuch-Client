import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pfad der mitgelieferten Lizenz der Hausschrift.
const fontLicenseAsset = 'assets/fonts/OFL-AtkinsonHyperlegibleNext.txt';

/// Trägt die SIL-OFL-Lizenz von Atkinson Hyperlegible Next in die
/// Lizenzübersicht der App ein (showLicensePage / Einstellungen).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(fontLicenseAsset);
    yield LicenseEntryWithLineBreaks(['Atkinson Hyperlegible Next'], text);
  });
}
