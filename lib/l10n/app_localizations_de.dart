// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'PDF-Compressor';

  @override
  String get appSubtitle => 'Einfach und offline PDF-Dateien verkleinern';

  @override
  String get featureOffline => '100% Offline';

  @override
  String get featurePrivacy => 'Datenschutz-sicher';

  @override
  String get textLossHintTitle => 'Seiten werden zu Bildern.';

  @override
  String get textLossHintBody =>
      'Text lässt sich danach nicht mehr markieren, kopieren oder durchsuchen. Ideal für Scans.';

  @override
  String get infoTooltip => 'Info';

  @override
  String get aboutTitle => 'Über die App';

  @override
  String get aboutAuthor => 'Autor';

  @override
  String get aboutTechnology => 'Technologie';

  @override
  String get aboutTechnologyValue => 'Programmiert in Flutter';

  @override
  String get aboutLicense => 'Lizenz';

  @override
  String get aboutLicenseValue => 'Code unter Apache License 2.0';

  @override
  String get close => 'Schließen';

  @override
  String get pickPdf => 'PDF auswählen';

  @override
  String get compressNow => 'Jetzt verkleinern';

  @override
  String get chooseOtherFile => 'Andere Datei wählen';

  @override
  String get compressAnother => 'Weiteres PDF verkleinern';

  @override
  String get save => 'Speichern';

  @override
  String get share => 'Teilen';

  @override
  String originalSize(String size) {
    return 'Originalgröße: $size';
  }

  @override
  String compressionStrength(String level) {
    return 'Kompressionsstärke: $level';
  }

  @override
  String get levelLight => 'Leicht (Hohe Qualität, 150 DPI)';

  @override
  String get levelRecommended => 'Empfohlen (Gute Balance, 110 DPI)';

  @override
  String get levelStrong => 'Stark (Kleinste Datei, 72 DPI)';

  @override
  String processingPage(int page) {
    return 'Verarbeite Seite $page...';
  }

  @override
  String get newSize => 'Neue Größe:';

  @override
  String get alreadyOptimal => 'Bereits optimal';

  @override
  String get keptOriginalHint =>
      'Diese PDF lässt sich nicht weiter verkleinern. Das Original wird unverändert übernommen.';

  @override
  String errorOpenFile(String error) {
    return 'Fehler beim Öffnen der Datei: $error';
  }

  @override
  String errorCompress(String error) {
    return 'Fehler bei der Komprimierung: $error';
  }

  @override
  String errorRenderPage(int page) {
    return 'Seite $page konnte nicht verarbeitet werden. Die PDF wurde nicht verkleinert.';
  }

  @override
  String errorSave(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get saveDialogTitle => 'Komprimierte PDF speichern';

  @override
  String get savedSuccess => 'PDF erfolgreich auf dem Gerät gespeichert!';

  @override
  String get shareText => 'Komprimiert mit PDF-Compressor';

  @override
  String get compressedFileSuffix => 'komprimiert';
}
