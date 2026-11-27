// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PDF Compressor';

  @override
  String get appSubtitle => 'Shrink PDF files easily and offline';

  @override
  String get featureOffline => '100% Offline';

  @override
  String get featurePrivacy => 'Privacy-friendly';

  @override
  String get infoTooltip => 'Info';

  @override
  String get aboutTitle => 'About the app';

  @override
  String get aboutAuthor => 'Author';

  @override
  String get aboutTechnology => 'Technology';

  @override
  String get aboutTechnologyValue => 'Built with Flutter';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutLicenseValue => 'Code under Apache License 2.0';

  @override
  String get close => 'Close';

  @override
  String get pickPdf => 'Choose PDF';

  @override
  String get compressNow => 'Compress now';

  @override
  String get chooseOtherFile => 'Choose another file';

  @override
  String get compressAnother => 'Compress another PDF';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String originalSize(String size) {
    return 'Original size: $size';
  }

  @override
  String compressionStrength(String level) {
    return 'Compression level: $level';
  }

  @override
  String get levelLight => 'Light (High quality, 150 DPI)';

  @override
  String get levelRecommended => 'Recommended (Good balance, 110 DPI)';

  @override
  String get levelStrong => 'Strong (Smallest file, 72 DPI)';

  @override
  String processingPage(int page) {
    return 'Processing page $page...';
  }

  @override
  String get newSize => 'New size:';

  @override
  String get alreadyOptimal => 'Already optimal';

  @override
  String get keptOriginalHint =>
      'This PDF can\'t be made any smaller. The original is kept unchanged.';

  @override
  String errorOpenFile(String error) {
    return 'Error opening the file: $error';
  }

  @override
  String errorCompress(String error) {
    return 'Error during compression: $error';
  }

  @override
  String errorRenderPage(int page) {
    return 'Page $page could not be processed. The PDF was not compressed.';
  }

  @override
  String errorSave(String error) {
    return 'Error while saving: $error';
  }

  @override
  String get saveDialogTitle => 'Save compressed PDF';

  @override
  String get savedSuccess => 'PDF saved to your device!';

  @override
  String get shareText => 'Compressed with PDF Compressor';

  @override
  String get compressedFileSuffix => 'compressed';
}
