import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licence texts of bundled data and fonts (R1-release), added to Flutter's
/// Open-source packages page: the SIL OFL 1.1 for Noto Sans (the OFL asks for its
/// text to travel with the font) and Britfone's MIT licence.
const Map<String, String> bundledLicenceAssets = {
  'Noto Sans (font)': 'assets/fonts/NotoSans-OFL.txt',
  'Britfone (dictionary)': 'assets/content/BRITFONE_LICENSE.txt',
};

bool _registered = false;

/// Registers [bundledLicenceAssets] with [LicenseRegistry] once; later calls do
/// nothing. A missing asset is skipped rather than breaking the page.
void registerBundledLicences({AssetBundle? bundle}) {
  if (_registered) return;
  _registered = true;
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: package, value: path)
        in bundledLicenceAssets.entries) {
      try {
        yield LicenseEntryWithLineBreaks([
          package,
        ], await assets.loadString(path));
      } on Object {
        // Not bundled in this build (e.g. a test bundle): leave it out.
      }
    }
  });
}

/// Lets tests register again with another bundle.
@visibleForTesting
void resetBundledLicencesForTest() => _registered = false;
