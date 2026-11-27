import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'PDF-Compressor'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Einfach und offline PDF-Dateien verkleinern'**
  String get appSubtitle;

  /// No description provided for @featureOffline.
  ///
  /// In de, this message translates to:
  /// **'100% Offline'**
  String get featureOffline;

  /// No description provided for @featurePrivacy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz-sicher'**
  String get featurePrivacy;

  /// No description provided for @textLossHintTitle.
  ///
  /// In de, this message translates to:
  /// **'Seiten werden zu Bildern.'**
  String get textLossHintTitle;

  /// No description provided for @textLossHintBody.
  ///
  /// In de, this message translates to:
  /// **'Text lässt sich danach nicht mehr markieren, kopieren oder durchsuchen. Ideal für Scans.'**
  String get textLossHintBody;

  /// No description provided for @infoTooltip.
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get infoTooltip;

  /// No description provided for @aboutTitle.
  ///
  /// In de, this message translates to:
  /// **'Über die App'**
  String get aboutTitle;

  /// No description provided for @aboutAuthor.
  ///
  /// In de, this message translates to:
  /// **'Autor'**
  String get aboutAuthor;

  /// No description provided for @aboutTechnology.
  ///
  /// In de, this message translates to:
  /// **'Technologie'**
  String get aboutTechnology;

  /// No description provided for @aboutTechnologyValue.
  ///
  /// In de, this message translates to:
  /// **'Programmiert in Flutter'**
  String get aboutTechnologyValue;

  /// No description provided for @aboutLicense.
  ///
  /// In de, this message translates to:
  /// **'Lizenz'**
  String get aboutLicense;

  /// No description provided for @aboutLicenseValue.
  ///
  /// In de, this message translates to:
  /// **'Code unter Apache License 2.0'**
  String get aboutLicenseValue;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @pickPdf.
  ///
  /// In de, this message translates to:
  /// **'PDF auswählen'**
  String get pickPdf;

  /// No description provided for @compressNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt verkleinern'**
  String get compressNow;

  /// No description provided for @chooseOtherFile.
  ///
  /// In de, this message translates to:
  /// **'Andere Datei wählen'**
  String get chooseOtherFile;

  /// No description provided for @compressAnother.
  ///
  /// In de, this message translates to:
  /// **'Weiteres PDF verkleinern'**
  String get compressAnother;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @share.
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get share;

  /// No description provided for @originalSize.
  ///
  /// In de, this message translates to:
  /// **'Originalgröße: {size}'**
  String originalSize(String size);

  /// No description provided for @compressionStrength.
  ///
  /// In de, this message translates to:
  /// **'Kompressionsstärke: {level}'**
  String compressionStrength(String level);

  /// No description provided for @levelLight.
  ///
  /// In de, this message translates to:
  /// **'Leicht (Hohe Qualität, 150 DPI)'**
  String get levelLight;

  /// No description provided for @levelRecommended.
  ///
  /// In de, this message translates to:
  /// **'Empfohlen (Gute Balance, 110 DPI)'**
  String get levelRecommended;

  /// No description provided for @levelStrong.
  ///
  /// In de, this message translates to:
  /// **'Stark (Kleinste Datei, 72 DPI)'**
  String get levelStrong;

  /// No description provided for @processingPage.
  ///
  /// In de, this message translates to:
  /// **'Verarbeite Seite {page}...'**
  String processingPage(int page);

  /// No description provided for @newSize.
  ///
  /// In de, this message translates to:
  /// **'Neue Größe:'**
  String get newSize;

  /// No description provided for @alreadyOptimal.
  ///
  /// In de, this message translates to:
  /// **'Bereits optimal'**
  String get alreadyOptimal;

  /// No description provided for @keptOriginalHint.
  ///
  /// In de, this message translates to:
  /// **'Diese PDF lässt sich nicht weiter verkleinern. Das Original wird unverändert übernommen.'**
  String get keptOriginalHint;

  /// No description provided for @errorOpenFile.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Öffnen der Datei: {error}'**
  String errorOpenFile(String error);

  /// No description provided for @errorCompress.
  ///
  /// In de, this message translates to:
  /// **'Fehler bei der Komprimierung: {error}'**
  String errorCompress(String error);

  /// No description provided for @errorRenderPage.
  ///
  /// In de, this message translates to:
  /// **'Seite {page} konnte nicht verarbeitet werden. Die PDF wurde nicht verkleinert.'**
  String errorRenderPage(int page);

  /// No description provided for @errorSave.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Speichern: {error}'**
  String errorSave(String error);

  /// No description provided for @saveDialogTitle.
  ///
  /// In de, this message translates to:
  /// **'Komprimierte PDF speichern'**
  String get saveDialogTitle;

  /// No description provided for @savedSuccess.
  ///
  /// In de, this message translates to:
  /// **'PDF erfolgreich auf dem Gerät gespeichert!'**
  String get savedSuccess;

  /// No description provided for @shareText.
  ///
  /// In de, this message translates to:
  /// **'Komprimiert mit PDF-Compressor'**
  String get shareText;

  /// Wird an den Dateinamen angehängt: <name>_<suffix>.pdf. Nur Buchstaben, keine Leerzeichen.
  ///
  /// In de, this message translates to:
  /// **'komprimiert'**
  String get compressedFileSuffix;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
