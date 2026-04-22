import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ta'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CrisisNet'**
  String get appName;

  /// No description provided for @sosButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'SEND SOS'**
  String get sosButtonLabel;

  /// No description provided for @sosButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Press to alert emergency staff'**
  String get sosButtonHint;

  /// No description provided for @sosRecordingLabel.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get sosRecordingLabel;

  /// No description provided for @sosTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency Type'**
  String get sosTypeLabel;

  /// No description provided for @sosRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room / Location'**
  String get sosRoomLabel;

  /// No description provided for @sosDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what is happening...'**
  String get sosDescriptionHint;

  /// No description provided for @sosAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach Photo'**
  String get sosAttachPhoto;

  /// No description provided for @sosRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get sosRemovePhoto;

  /// No description provided for @sosSending.
  ///
  /// In en, this message translates to:
  /// **'Sending SOS...'**
  String get sosSending;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS Sent'**
  String get sosSent;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Status'**
  String get statusTitle;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response...'**
  String get statusWaiting;

  /// No description provided for @statusTriaged.
  ///
  /// In en, this message translates to:
  /// **'Triaged by AI'**
  String get statusTriaged;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Staff Dispatched'**
  String get statusAssigned;

  /// No description provided for @statusEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated to Emergency Services'**
  String get statusEscalated;

  /// No description provided for @statusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get statusResolved;

  /// No description provided for @statusContained.
  ///
  /// In en, this message translates to:
  /// **'Contained'**
  String get statusContained;

  /// No description provided for @statusInstructions.
  ///
  /// In en, this message translates to:
  /// **'Safety Instructions'**
  String get statusInstructions;

  /// No description provided for @statusRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get statusRoom;

  /// No description provided for @statusType.
  ///
  /// In en, this message translates to:
  /// **'Emergency Type'**
  String get statusType;

  /// No description provided for @typeFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get typeFire;

  /// No description provided for @typeMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get typeMedical;

  /// No description provided for @typeSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get typeSecurity;

  /// No description provided for @typeInfrastructure.
  ///
  /// In en, this message translates to:
  /// **'Infrastructure'**
  String get typeInfrastructure;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @statusOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open Chat'**
  String get statusOpenChat;

  /// No description provided for @statusBack.
  ///
  /// In en, this message translates to:
  /// **'Report Another Emergency'**
  String get statusBack;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Chat'**
  String get chatTitle;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatPlaceholder;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get chatConnecting;

  /// No description provided for @offlineWarning.
  ///
  /// In en, this message translates to:
  /// **'No internet — using offline safety guide'**
  String get offlineWarning;

  /// No description provided for @offlineGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Safety Guide'**
  String get offlineGuideTitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location.'**
  String get errorNoLocation;

  /// No description provided for @errorSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send SOS. Please call reception.'**
  String get errorSendFailed;
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
      <String>['en', 'es', 'fr', 'hi', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
