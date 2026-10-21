import 'dart:math' as math;

import 'package:advanced_geofence/advanced_geofence.dart';

const double metersPerDegree = earthRadiusMeters * math.pi / 180;

/// [origin] moved [north] and [east] meters (small offsets only).
GeoPoint offset(GeoPoint origin, {double north = 0, double east = 0, double? accuracy, DateTime? time}) {
  final lat = origin.latitude + north / metersPerDegree;
  final lng = origin.longitude + east / (metersPerDegree * math.cos(origin.latitude * math.pi / 180));
  return GeoPoint(lat, lng, accuracy: accuracy, time: time);
}

final DateTime t0 = DateTime.utc(2026, 10, 22, 9);

DateTime at(int seconds) => t0.add(Duration(seconds: seconds));
