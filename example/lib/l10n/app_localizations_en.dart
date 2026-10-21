// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Geofence monitor';

  @override
  String get appSubtitle => 'advanced_geofence · background location';

  @override
  String get statusActive => 'Monitoring active';

  @override
  String get statusInactive => 'Monitoring off';

  @override
  String get statusActiveDescription => 'Zone events are detected even when the app is in the background.';

  @override
  String get statusInactiveDescription => 'Start monitoring to detect when you enter or leave your zones.';

  @override
  String get badgeLive => 'Live';

  @override
  String get badgeIdle => 'Idle';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get stopMonitoring => 'Stop monitoring';

  @override
  String get sectionPosition => 'Current position';

  @override
  String get waitingForLocation => 'Waiting for the first location…';

  @override
  String get noLocationYet => 'Start monitoring to see your position.';

  @override
  String get metricLatitude => 'Latitude';

  @override
  String get metricLongitude => 'Longitude';

  @override
  String get metricAccuracy => 'Accuracy';

  @override
  String get metricTime => 'Time';

  @override
  String readingIgnored(String reason) {
    return 'Last reading ignored: $reason';
  }

  @override
  String get ignoredLowAccuracy => 'low accuracy';

  @override
  String get ignoredStale => 'too old';

  @override
  String get ignoredOutOfOrder => 'out of order';

  @override
  String get ignoredInvalid => 'invalid coordinates';

  @override
  String get addZoneHere => 'Add zone here';

  @override
  String get sectionZones => 'Zones';

  @override
  String zoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count zones', one: '1 zone');
    return '$_temp0';
  }

  @override
  String get noZones => 'No zones yet. Start monitoring, then add a zone at your position.';

  @override
  String zoneDetails(String radius) {
    return 'Radius $radius · dwell after 1 min';
  }

  @override
  String zoneDistance(String distance) {
    return '$distance from the boundary';
  }

  @override
  String get statusInside => 'Inside';

  @override
  String get statusOutside => 'Outside';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get deleteZone => 'Delete zone';

  @override
  String get sectionEvents => 'Events';

  @override
  String eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count events', one: '1 event');
    return '$_temp0';
  }

  @override
  String get noEvents => 'No events yet.';

  @override
  String eventEnter(String name) {
    return 'Entered $name';
  }

  @override
  String eventExit(String name) {
    return 'Left $name';
  }

  @override
  String eventDwell(String name) {
    return 'Staying at $name';
  }

  @override
  String get eventInitial => 'already inside at start';

  @override
  String get clearEvents => 'Clear events';

  @override
  String get addZoneTitle => 'New zone';

  @override
  String get zoneName => 'Name';

  @override
  String zoneNameDefault(int number) {
    return 'Zone $number';
  }

  @override
  String get zoneRadius => 'Radius';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String unitMeters(String value) {
    return '$value m';
  }

  @override
  String get settingsSummary => 'Hysteresis 20 m  ·  2 confirmations  ·  max. accuracy 100 m';

  @override
  String get permissionDenied => 'Location permission was not granted.';

  @override
  String get notificationChannelName => 'Geofence monitoring';

  @override
  String get notificationTitle => 'Geofence monitoring active';

  @override
  String get notificationMessage => 'Your zones are watched in the background';

  @override
  String get notificationBigMessage =>
      'Location is used in the background to detect when you enter or leave your zones.';
}
