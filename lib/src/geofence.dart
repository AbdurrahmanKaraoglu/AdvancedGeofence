import 'geo_bounds.dart';
import 'geo_math.dart';
import 'geo_point.dart';
import 'json_util.dart';

/// A region to monitor: a [CircleGeofence] or a [PolygonGeofence].
sealed class Geofence {
  Geofence._({required this.id, this.name, Map<String, Object?>? metadata, this.dwellTime})
    : metadata = Map.unmodifiable(metadata ?? const {}) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    if (dwellTime != null && dwellTime!.isNegative) {
      throw ArgumentError.value(dwellTime, 'dwellTime', 'must not be negative');
    }
  }

  /// Recreates a geofence from [toJson] output.
  ///
  /// Throws a [FormatException] if [json] is malformed.
  factory Geofence.fromJson(Map<String, Object?> json) => parseJson('geofence', () => _fromJson(json));

  static Geofence _fromJson(Map<String, Object?> json) {
    final metadata = (json['metadata'] as Map?)?.cast<String, Object?>();
    final dwellMs = json['dwellMs'] as num?;
    final dwell = dwellMs == null ? null : Duration(milliseconds: dwellMs.toInt());
    final id = json['id'] as String;
    final name = json['name'] as String?;
    switch (json['type']) {
      case 'circle':
        return CircleGeofence(
          id: id,
          name: name,
          metadata: metadata,
          dwellTime: dwell,
          center: GeoPoint.fromJson((json['center'] as Map).cast<String, Object?>()),
          radius: (json['radius'] as num).toDouble(),
        );
      case 'polygon':
        return PolygonGeofence(
          id: id,
          name: name,
          metadata: metadata,
          dwellTime: dwell,
          vertices: [
            for (final v in json['vertices'] as List)
              GeoPoint(((v as List)[0] as num).toDouble(), (v[1] as num).toDouble()),
          ],
        );
      default:
        throw FormatException('Unknown geofence type: ${json['type']}');
    }
  }

  /// Unique identifier. Events and saved state refer to geofences by id.
  final String id;

  /// Optional human readable name.
  final String? name;

  /// Free-form data attached to the geofence (e.g. a database key).
  ///
  /// Keep values JSON encodable if you use [toJson].
  final Map<String, Object?> metadata;

  /// How long the device must stay inside before a dwell event is emitted.
  ///
  /// `null` falls back to `GeofenceOptions.defaultDwellTime`; when both are
  /// `null` this geofence never emits dwell events.
  final Duration? dwellTime;

  /// The smallest box that contains the geofence.
  GeoBounds get bounds;

  /// Signed distance from [point] to the boundary in meters: negative inside,
  /// positive outside.
  double signedDistance(GeoPoint point);

  /// Whether [point] is inside (or on the boundary of) the geofence.
  bool contains(GeoPoint point) => signedDistance(point) <= 0;

  /// JSON representation. See [Geofence.fromJson].
  Map<String, Object?> toJson();

  Map<String, Object?> _baseJson(String type) => {
    'type': type,
    'id': id,
    if (name != null) 'name': name,
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (dwellTime != null) 'dwellMs': dwellTime!.inMilliseconds,
  };
}

/// A circular geofence: every point within [radius] meters of [center].
final class CircleGeofence extends Geofence {
  /// Creates a circle. [radius] is in meters and must be positive.
  CircleGeofence({
    required super.id,
    required this.center,
    required this.radius,
    super.name,
    super.metadata,
    super.dwellTime,
  }) : super._() {
    if (!center.isValid) throw ArgumentError.value(center, 'center', 'invalid coordinates');
    if (!(radius > 0) || !radius.isFinite) {
      throw ArgumentError.value(radius, 'radius', 'must be a positive number of meters');
    }
    final lngSpan = circleLongitudeSpan(center.latitude, radius);
    final latSpan = radius / metersPerDegree;
    final lng = normalizeLongitude(center.longitude);
    bounds = GeoBounds.fromUnwrapped(
      south: (center.latitude - latSpan).clamp(-90.0, 90.0),
      north: (center.latitude + latSpan).clamp(-90.0, 90.0),
      minLng: lngSpan == null ? -180 : lng - lngSpan,
      maxLng: lngSpan == null ? 180 : lng + lngSpan,
    );
  }

  /// Center of the circle.
  final GeoPoint center;

  /// Radius in meters.
  final double radius;

  @override
  late final GeoBounds bounds;

  @override
  double signedDistance(GeoPoint point) =>
      haversineDistance(center.latitude, center.longitude, point.latitude, point.longitude) - radius;

  @override
  Map<String, Object?> toJson() => {
    ..._baseJson('circle'),
    'center': {'lat': center.latitude, 'lng': center.longitude},
    'radius': radius,
  };

  @override
  String toString() => 'CircleGeofence($id, ${center.latitude}, ${center.longitude}, ${radius}m)';
}

/// A polygonal geofence.
///
/// Edges are straight lines in latitude/longitude space and inside/outside
/// is decided by ray casting (even-odd rule), so self-intersecting polygons
/// have "holes" where they overlap. Polygons may cross the antimeridian but
/// must not enclose a pole (use a [CircleGeofence] for polar regions), and
/// consecutive vertices must be less than 180° of longitude apart.
/// Distances to the boundary use a local planar approximation, which is
/// accurate for geofences up to a few tens of kilometers.
final class PolygonGeofence extends Geofence {
  /// Creates a polygon from at least three [vertices]. Closing the ring
  /// (repeating the first vertex at the end) is optional.
  PolygonGeofence({required super.id, required List<GeoPoint> vertices, super.name, super.metadata, super.dwellTime})
    : vertices = List.unmodifiable(_withoutClosingVertex(vertices)),
      super._() {
    if (this.vertices.length < 3) {
      throw ArgumentError.value(vertices.length, 'vertices', 'a polygon needs at least 3 vertices');
    }
    for (final v in this.vertices) {
      if (!v.isValid) throw ArgumentError.value(v, 'vertices', 'invalid coordinates');
    }

    // Unwrap longitudes so that consecutive vertices are never more than 180°
    // apart; a polygon crossing the antimeridian then has a continuous range.
    final lats = <double>[];
    final lngs = <double>[];
    var winding = 0.0;
    var previous = normalizeLongitude(this.vertices.first.longitude);
    for (var i = 0; i < this.vertices.length; i++) {
      final v = this.vertices[i];
      final lng = i == 0 ? previous : previous + _wrapDelta(normalizeLongitude(v.longitude) - previous);
      winding += lng - previous;
      lats.add(v.latitude);
      lngs.add(lng);
      previous = lng;
    }
    winding += _wrapDelta(lngs.first - previous);
    if (winding.abs() > 180) {
      throw ArgumentError('Polygons enclosing a pole are not supported; use a CircleGeofence.');
    }
    if (!_hasArea(lats, lngs)) {
      throw ArgumentError.value(vertices, 'vertices', 'all vertices are on one line; the polygon has no area');
    }
    _lats = lats;
    _lngs = lngs;

    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (var i = 0; i < lats.length; i++) {
      if (lats[i] < minLat) minLat = lats[i];
      if (lats[i] > maxLat) maxLat = lats[i];
      if (lngs[i] < minLng) minLng = lngs[i];
      if (lngs[i] > maxLng) maxLng = lngs[i];
    }
    _midLng = (minLng + maxLng) / 2;
    bounds = GeoBounds.fromUnwrapped(south: minLat, north: maxLat, minLng: minLng, maxLng: maxLng);
  }

  /// The polygon's vertices, without a repeated closing vertex.
  final List<GeoPoint> vertices;

  late final List<double> _lats;
  late final List<double> _lngs;
  late final double _midLng;

  @override
  late final GeoBounds bounds;

  static List<GeoPoint> _withoutClosingVertex(List<GeoPoint> vertices) {
    if (vertices.length > 1) {
      final first = vertices.first, last = vertices.last;
      if (first.latitude == last.latitude &&
          normalizeLongitude(first.longitude) == normalizeLongitude(last.longitude)) {
        return vertices.sublist(0, vertices.length - 1);
      }
    }
    return vertices;
  }

  /// Whether the vertices are not all on one line.
  static bool _hasArea(List<double> lats, List<double> lngs) {
    final x0 = lngs[0], y0 = lats[0];
    var i = 1;
    while (i < lats.length && lngs[i] == x0 && lats[i] == y0) {
      i++;
    }
    if (i == lats.length) return false;
    final dx = lngs[i] - x0, dy = lats[i] - y0;
    for (var k = i + 1; k < lats.length; k++) {
      // Cross product in degrees²; 1e-14 is far below a square centimeter.
      if ((dx * (lats[k] - y0) - dy * (lngs[k] - x0)).abs() > 1e-14) return true;
    }
    return false;
  }

  static double _wrapDelta(double delta) {
    if (delta >= 180) return delta - 360;
    if (delta < -180) return delta + 360;
    return delta;
  }

  /// The query longitude shifted by ±360° into the polygon's unwrapped range.
  double _shift(double longitude) {
    var lng = normalizeLongitude(longitude);
    while (lng - _midLng > 180) {
      lng -= 360;
    }
    while (_midLng - lng > 180) {
      lng += 360;
    }
    return lng;
  }

  bool _rayCast(double lat, double lng) {
    var inside = false;
    final n = _lats.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = _lats[i], yj = _lats[j];
      if ((yi > lat) != (yj > lat)) {
        final xi = _lngs[i], xj = _lngs[j];
        final x = xi + (lat - yi) / (yj - yi) * (xj - xi);
        if (lng < x) inside = !inside;
      }
    }
    return inside;
  }

  double _distanceToEdges(double lat, double lng) {
    final kx = cosLatitude(lat) * metersPerDegree;
    var best = double.infinity;
    final n = _lats.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final d = distanceToSegment(
        (_lngs[j] - lng) * kx,
        (_lats[j] - lat) * metersPerDegree,
        (_lngs[i] - lng) * kx,
        (_lats[i] - lat) * metersPerDegree,
      );
      if (d < best) best = d;
    }
    return best;
  }

  @override
  bool contains(GeoPoint point) {
    if (!bounds.contains(point)) return false;
    return _rayCast(point.latitude, _shift(point.longitude)) ||
        _distanceToEdges(point.latitude, _shift(point.longitude)) == 0;
  }

  @override
  double signedDistance(GeoPoint point) {
    final lng = _shift(point.longitude);
    final distance = _distanceToEdges(point.latitude, lng);
    final inside = bounds.contains(point) && _rayCast(point.latitude, lng);
    return inside ? -distance : distance;
  }

  @override
  Map<String, Object?> toJson() => {
    ..._baseJson('polygon'),
    'vertices': [
      for (final v in vertices) [v.latitude, v.longitude],
    ],
  };

  @override
  String toString() => 'PolygonGeofence($id, ${vertices.length} vertices)';
}
