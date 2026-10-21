import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('tr')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Geofence monitor'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'advanced_geofence · background location'**
  String get appSubtitle;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Monitoring active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Monitoring off'**
  String get statusInactive;

  /// No description provided for @statusActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Zone events are detected even when the app is in the background.'**
  String get statusActiveDescription;

  /// No description provided for @statusInactiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring to detect when you enter or leave your zones.'**
  String get statusInactiveDescription;

  /// No description provided for @badgeLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get badgeLive;

  /// No description provided for @badgeIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get badgeIdle;

  /// No description provided for @startMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring'**
  String get startMonitoring;

  /// No description provided for @stopMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Stop monitoring'**
  String get stopMonitoring;

  /// No description provided for @sectionPosition.
  ///
  /// In en, this message translates to:
  /// **'Current position'**
  String get sectionPosition;

  /// No description provided for @waitingForLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first location…'**
  String get waitingForLocation;

  /// No description provided for @noLocationYet.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring to see your position.'**
  String get noLocationYet;

  /// No description provided for @metricLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get metricLatitude;

  /// No description provided for @metricLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get metricLongitude;

  /// No description provided for @metricAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get metricAccuracy;

  /// No description provided for @metricTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get metricTime;

  /// No description provided for @readingIgnored.
  ///
  /// In en, this message translates to:
  /// **'Last reading ignored: {reason}'**
  String readingIgnored(String reason);

  /// No description provided for @ignoredLowAccuracy.
  ///
  /// In en, this message translates to:
  /// **'low accuracy'**
  String get ignoredLowAccuracy;

  /// No description provided for @ignoredStale.
  ///
  /// In en, this message translates to:
  /// **'too old'**
  String get ignoredStale;

  /// No description provided for @ignoredOutOfOrder.
  ///
  /// In en, this message translates to:
  /// **'out of order'**
  String get ignoredOutOfOrder;

  /// No description provided for @ignoredInvalid.
  ///
  /// In en, this message translates to:
  /// **'invalid coordinates'**
  String get ignoredInvalid;

  /// No description provided for @addZoneHere.
  ///
  /// In en, this message translates to:
  /// **'Add zone here'**
  String get addZoneHere;

  /// No description provided for @sectionZones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get sectionZones;

  /// No description provided for @zoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone} other{{count} zones}}'**
  String zoneCount(int count);

  /// No description provided for @noZones.
  ///
  /// In en, this message translates to:
  /// **'No zones yet. Start monitoring, then add a zone at your position.'**
  String get noZones;

  /// No description provided for @zoneDetails.
  ///
  /// In en, this message translates to:
  /// **'Radius {radius} · dwell after 1 min'**
  String zoneDetails(String radius);

  /// No description provided for @zoneDistance.
  ///
  /// In en, this message translates to:
  /// **'{distance} from the boundary'**
  String zoneDistance(String distance);

  /// No description provided for @statusInside.
  ///
  /// In en, this message translates to:
  /// **'Inside'**
  String get statusInside;

  /// No description provided for @statusOutside.
  ///
  /// In en, this message translates to:
  /// **'Outside'**
  String get statusOutside;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @deleteZone.
  ///
  /// In en, this message translates to:
  /// **'Delete zone'**
  String get deleteZone;

  /// No description provided for @sectionEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get sectionEvents;

  /// No description provided for @eventCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String eventCount(int count);

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get noEvents;

  /// No description provided for @eventEnter.
  ///
  /// In en, this message translates to:
  /// **'Entered {name}'**
  String eventEnter(String name);

  /// No description provided for @eventExit.
  ///
  /// In en, this message translates to:
  /// **'Left {name}'**
  String eventExit(String name);

  /// No description provided for @eventDwell.
  ///
  /// In en, this message translates to:
  /// **'Staying at {name}'**
  String eventDwell(String name);

  /// No description provided for @eventInitial.
  ///
  /// In en, this message translates to:
  /// **'already inside at start'**
  String get eventInitial;

  /// No description provided for @clearEvents.
  ///
  /// In en, this message translates to:
  /// **'Clear events'**
  String get clearEvents;

  /// No description provided for @addZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'New zone'**
  String get addZoneTitle;

  /// No description provided for @zoneName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get zoneName;

  /// No description provided for @zoneNameDefault.
  ///
  /// In en, this message translates to:
  /// **'Zone {number}'**
  String zoneNameDefault(int number);

  /// No description provided for @zoneRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get zoneRadius;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String unitMeters(String value);

  /// No description provided for @settingsSummary.
  ///
  /// In en, this message translates to:
  /// **'Hysteresis 20 m  ·  2 confirmations  ·  max. accuracy 100 m'**
  String get settingsSummary;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted.'**
  String get permissionDenied;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Geofence monitoring'**
  String get notificationChannelName;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Geofence monitoring active'**
  String get notificationTitle;

  /// No description provided for @notificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your zones are watched in the background'**
  String get notificationMessage;

  /// No description provided for @notificationBigMessage.
  ///
  /// In en, this message translates to:
  /// **'Location is used in the background to detect when you enter or leave your zones.'**
  String get notificationBigMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
