import 'geo_math.dart';
import 'geo_point.dart';

/// A latitude/longitude bounding box.
///
/// When [west] is greater than [east] the box crosses the antimeridian
/// (180°), e.g. west 179, east -179 is a 2° wide box around 180°.
class GeoBounds {
  /// Creates a box. Longitudes are wrapped into -180..180.
  GeoBounds({required this.south, required this.north, required double west, required double east})
    : west = west == 180 ? 180 : normalizeLongitude(west),
      east = east == 180 ? 180 : normalizeLongitude(east) {
    if (south > north) {
      throw ArgumentError('south ($south) must not be greater than north ($north)');
    }
  }

  /// A box from a longitude range that may extend past ±180 (an unwrapped
  /// range). Spans of 360° or more cover all longitudes.
  factory GeoBounds.fromUnwrapped({
    required double south,
    required double north,
    required double minLng,
    required double maxLng,
  }) {
    if (maxLng - minLng >= 360) {
      return GeoBounds(south: south, north: north, west: -180, east: 180);
    }
    return GeoBounds(south: south, north: north, west: minLng, east: maxLng);
  }

  /// Southern edge (minimum latitude) in degrees.
  final double south;

  /// Northern edge (maximum latitude) in degrees.
  final double north;

  /// Western edge in degrees, -180..180.
  final double west;

  /// Eastern edge in degrees, -180..180.
  final double east;

  /// Whether the box crosses the antimeridian.
  bool get crossesAntimeridian => west > east;

  /// Whether the box covers every longitude.
  bool get spansAllLongitudes => west == -180 && east == 180;

  /// Whether [point] lies inside the box (edges included).
  bool contains(GeoPoint point) => containsLatLng(point.latitude, normalizeLongitude(point.longitude));

  /// Whether the coordinates lie inside the box. [lng] must be normalized.
  bool containsLatLng(double lat, double lng) {
    if (lat < south || lat > north) return false;
    if (crossesAntimeridian) return lng >= west || lng <= east;
    return lng >= west && lng <= east;
  }

  /// The box grown by [meters] on every side (clamped at the poles).
  GeoBounds expand(double meters) {
    if (meters <= 0) return this;
    final dLat = meters / metersPerDegree;
    final s = (south - dLat).clamp(-90.0, 90.0);
    final n = (north + dLat).clamp(-90.0, 90.0);
    if (spansAllLongitudes || s <= -90 || n >= 90) {
      return GeoBounds(south: s, north: n, west: -180, east: 180);
    }
    final maxAbsLat = n.abs() > s.abs() ? n.abs() : s.abs();
    final dLng = meters / (metersPerDegree * cosLatitude(maxAbsLat));
    final width = crossesAntimeridian ? east + 360 - west : east - west;
    return GeoBounds.fromUnwrapped(south: s, north: n, minLng: west - dLng, maxLng: west + width + dLng);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoBounds && other.south == south && other.north == north && other.west == west && other.east == east;

  @override
  int get hashCode => Object.hash(south, north, west, east);

  @override
  String toString() => 'GeoBounds(S $south, N $north, W $west, E $east)';
}
