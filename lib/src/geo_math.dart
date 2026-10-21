import 'dart:math' as math;

import 'geo_point.dart';

/// Mean Earth radius in meters (IUGG).
const double earthRadiusMeters = 6371008.8;

const double _degToRad = math.pi / 180;
const double _radToDeg = 180 / math.pi;

/// Meters per degree of latitude (and of longitude at the equator).
const double metersPerDegree = earthRadiusMeters * _degToRad;

/// Wraps a longitude into the range [-180, 180).
double normalizeLongitude(double lng) {
  if (lng >= -180 && lng < 180) return lng;
  final wrapped = (lng + 180) % 360;
  return (wrapped < 0 ? wrapped + 360 : wrapped) - 180;
}

/// Great-circle distance in meters (haversine formula).
double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  final dLat = (lat2 - lat1) * _degToRad;
  final dLng = (lng2 - lng1) * _degToRad;
  final s1 = math.sin(dLat / 2);
  final s2 = math.sin(dLng / 2);
  final a = s1 * s1 + math.cos(lat1 * _degToRad) * math.cos(lat2 * _degToRad) * s2 * s2;
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
}

/// Great-circle distance in meters between two points.
double distanceBetween(GeoPoint a, GeoPoint b) => haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude);

/// Half-width in degrees of longitude of a circle of [radiusMeters] centered
/// at [latitude], or `null` when the circle reaches a pole (then it spans all
/// longitudes).
double? circleLongitudeSpan(double latitude, double radiusMeters) {
  final angular = radiusMeters / earthRadiusMeters;
  final latSpan = angular * _radToDeg;
  if (latitude + latSpan >= 90 || latitude - latSpan <= -90) return null;
  final ratio = math.sin(angular) / math.cos(latitude * _degToRad);
  if (ratio >= 1) return null;
  return math.asin(ratio) * _radToDeg;
}

/// Distance in meters from the origin to the segment (ax, ay)-(bx, by) in a
/// local planar frame.
double distanceToSegment(double ax, double ay, double bx, double by) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  var t = lengthSquared == 0 ? 0.0 : -(ax * dx + ay * dy) / lengthSquared;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final px = ax + t * dx;
  final py = ay + t * dy;
  return math.sqrt(px * px + py * py);
}

/// cos(latitude) for the local equirectangular projection.
double cosLatitude(double latitude) => math.cos(latitude * _degToRad);
