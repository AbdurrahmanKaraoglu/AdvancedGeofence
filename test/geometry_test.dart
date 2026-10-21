import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const istanbul = GeoPoint(41.0082, 28.9784);

  group('distance', () {
    test('one degree of latitude is about 111.2 km', () {
      expect(distanceBetween(const GeoPoint(0, 0), const GeoPoint(1, 0)), closeTo(111195, 1));
    });

    test('Istanbul to Ankara is about 350 km', () {
      expect(distanceBetween(istanbul, const GeoPoint(39.9334, 32.8597)), closeTo(350e3, 5e3));
    });

    test('works across the antimeridian', () {
      expect(distanceBetween(const GeoPoint(0, 179.999), const GeoPoint(0, -179.999)), closeTo(222.4, 0.5));
    });
  });

  group('GeoBounds', () {
    test('normal box', () {
      final b = GeoBounds(south: 10, north: 20, west: 30, east: 40);
      expect(b.crossesAntimeridian, isFalse);
      expect(b.contains(const GeoPoint(15, 35)), isTrue);
      expect(b.contains(const GeoPoint(15, 41)), isFalse);
      expect(b.contains(const GeoPoint(21, 35)), isFalse);
    });

    test('box crossing the antimeridian', () {
      final b = GeoBounds.fromUnwrapped(south: -1, north: 1, minLng: 179, maxLng: 181);
      expect(b.crossesAntimeridian, isTrue);
      expect(b.west, 179);
      expect(b.east, closeTo(-179, 1e-9));
      expect(b.contains(const GeoPoint(0, 179.5)), isTrue);
      expect(b.contains(const GeoPoint(0, -179.5)), isTrue);
      expect(b.contains(const GeoPoint(0, 180.5)), isTrue, reason: 'unnormalized input is wrapped');
      expect(b.contains(const GeoPoint(0, 0)), isFalse);
    });

    test('expand grows every side and can cross the antimeridian', () {
      final b = GeoBounds(south: 0, north: 0, west: 179.999, east: 179.999).expand(1000);
      expect(b.crossesAntimeridian, isTrue);
      expect(b.contains(const GeoPoint(0.005, -179.999)), isTrue);
      expect(b.contains(const GeoPoint(0.02, 179.999)), isFalse);
    });

    test('expand near a pole covers all longitudes', () {
      final b = GeoBounds(south: 89.99, north: 89.995, west: 10, east: 11).expand(2000);
      expect(b.spansAllLongitudes, isTrue);
      expect(b.north, 90);
    });

    test('rejects south > north', () {
      expect(() => GeoBounds(south: 2, north: 1, west: 0, east: 1), throwsArgumentError);
    });
  });

  group('CircleGeofence', () {
    final circle = CircleGeofence(id: 'c', center: istanbul, radius: 100);

    test('signed distance is negative inside and positive outside', () {
      expect(circle.signedDistance(istanbul), closeTo(-100, 1e-6));
      expect(circle.signedDistance(offset(istanbul, north: 60)), closeTo(-40, 0.1));
      expect(circle.signedDistance(offset(istanbul, east: 150)), closeTo(50, 0.1));
      expect(circle.contains(offset(istanbul, north: 99)), isTrue);
      expect(circle.contains(offset(istanbul, north: 101)), isFalse);
    });

    test('bounds contain the circle', () {
      for (final p in [
        offset(istanbul, north: 99.9),
        offset(istanbul, north: -99.9),
        offset(istanbul, east: 99.9),
        offset(istanbul, east: -99.9),
      ]) {
        expect(circle.bounds.contains(p), isTrue, reason: '$p');
      }
      expect(circle.bounds.contains(offset(istanbul, north: 101)), isFalse);
    });

    test('circle on the antimeridian', () {
      final c = CircleGeofence(id: 'am', center: const GeoPoint(-17, 180), radius: 5000);
      expect(c.bounds.crossesAntimeridian, isTrue);
      expect(c.contains(const GeoPoint(-17, 179.98)), isTrue);
      expect(c.contains(const GeoPoint(-17, -179.98)), isTrue);
      expect(c.contains(const GeoPoint(-17, 179.9)), isFalse);
    });

    test('circle containing the North Pole', () {
      final c = CircleGeofence(id: 'np', center: const GeoPoint(89.99, 0), radius: 5000);
      expect(c.bounds.spansAllLongitudes, isTrue);
      expect(c.contains(const GeoPoint(89.99, 180)), isTrue, reason: 'across the pole, ~2.2 km away');
      expect(c.contains(const GeoPoint(89.9, 90)), isFalse);
    });

    test('validates arguments', () {
      expect(() => CircleGeofence(id: 'x', center: istanbul, radius: 0), throwsArgumentError);
      expect(() => CircleGeofence(id: 'x', center: istanbul, radius: double.nan), throwsArgumentError);
      expect(() => CircleGeofence(id: 'x', center: const GeoPoint(91, 0), radius: 10), throwsArgumentError);
      expect(() => CircleGeofence(id: '', center: istanbul, radius: 10), throwsArgumentError);
    });
  });

  group('PolygonGeofence', () {
    // A ~200 m x 200 m square around Istanbul.
    final square = PolygonGeofence(
      id: 'sq',
      vertices: [
        offset(istanbul, north: -100, east: -100),
        offset(istanbul, north: -100, east: 100),
        offset(istanbul, north: 100, east: 100),
        offset(istanbul, north: 100, east: -100),
      ],
    );

    test('ray casting inside/outside', () {
      expect(square.contains(istanbul), isTrue);
      expect(square.contains(offset(istanbul, north: 99, east: 99)), isTrue);
      expect(square.contains(offset(istanbul, north: 101)), isFalse);
      expect(square.contains(offset(istanbul, east: -150)), isFalse);
    });

    test('signed distance to the nearest edge', () {
      expect(square.signedDistance(istanbul), closeTo(-100, 0.5));
      expect(square.signedDistance(offset(istanbul, north: 80)), closeTo(-20, 0.5));
      expect(square.signedDistance(offset(istanbul, east: 150)), closeTo(50, 0.5));
      // Diagonal outside a corner: distance to the corner.
      expect(square.signedDistance(offset(istanbul, north: 130, east: 140)), closeTo(50, 0.5));
    });

    test('concave polygon (L shape) excludes its notch', () {
      final l = PolygonGeofence(
        id: 'l',
        vertices: [
          offset(istanbul, north: 0, east: 0),
          offset(istanbul, north: 0, east: 200),
          offset(istanbul, north: 100, east: 200),
          offset(istanbul, north: 100, east: 100),
          offset(istanbul, north: 200, east: 100),
          offset(istanbul, north: 200, east: 0),
        ],
      );
      expect(l.contains(offset(istanbul, north: 50, east: 150)), isTrue);
      expect(l.contains(offset(istanbul, north: 150, east: 50)), isTrue);
      expect(l.contains(offset(istanbul, north: 150, east: 150)), isFalse, reason: 'the notch');
      expect(l.signedDistance(offset(istanbul, north: 150, east: 150)), closeTo(50, 0.5));
    });

    test('self-intersecting bow tie uses the even-odd rule', () {
      final bow = PolygonGeofence(
        id: 'bow',
        vertices: const [GeoPoint(0, 0), GeoPoint(1, 1), GeoPoint(1, 0), GeoPoint(0, 1)],
      );
      expect(bow.contains(const GeoPoint(0.1, 0.5)), isTrue);
      expect(bow.contains(const GeoPoint(0.9, 0.5)), isTrue);
      expect(bow.contains(const GeoPoint(0.5, 0.1)), isFalse);
    });

    test('a closing vertex is dropped', () {
      final p = PolygonGeofence(
        id: 'p',
        vertices: const [GeoPoint(0, 0), GeoPoint(0, 1), GeoPoint(1, 1), GeoPoint(0, 0)],
      );
      expect(p.vertices, hasLength(3));
    });

    test('polygon crossing the antimeridian', () {
      final fiji = PolygonGeofence(
        id: 'fiji',
        vertices: const [GeoPoint(-16, 179.5), GeoPoint(-16, -179.5), GeoPoint(-17, -179.5), GeoPoint(-17, 179.5)],
      );
      expect(fiji.bounds.crossesAntimeridian, isTrue);
      expect(fiji.contains(const GeoPoint(-16.5, 179.9)), isTrue);
      expect(fiji.contains(const GeoPoint(-16.5, -179.9)), isTrue);
      expect(fiji.contains(const GeoPoint(-16.5, 180)), isTrue);
      expect(fiji.contains(const GeoPoint(-16.5, 0)), isFalse);
      expect(fiji.contains(const GeoPoint(-16.5, 179)), isFalse);
      // 0.5° of longitude at -16.5° is ~53.3 km.
      expect(fiji.signedDistance(const GeoPoint(-16.5, 179)), closeTo(53300, 300));
    });

    test('rejects polygons that enclose a pole', () {
      expect(
        () => PolygonGeofence(
          id: 'arctic',
          vertices: const [GeoPoint(80, 0), GeoPoint(80, 90), GeoPoint(80, 180), GeoPoint(80, -90)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects fewer than three vertices', () {
      expect(() => PolygonGeofence(id: 'x', vertices: const [GeoPoint(0, 0), GeoPoint(1, 1)]), throwsArgumentError);
    });
  });

  group('JSON', () {
    test('circle round trip', () {
      final c = CircleGeofence(
        id: 'c',
        name: 'Office',
        center: istanbul,
        radius: 120,
        metadata: {'floor': 3},
        dwellTime: const Duration(minutes: 2),
      );
      final copy = Geofence.fromJson(c.toJson()) as CircleGeofence;
      expect(copy.id, 'c');
      expect(copy.name, 'Office');
      expect(copy.center.latitude, istanbul.latitude);
      expect(copy.radius, 120);
      expect(copy.metadata, {'floor': 3});
      expect(copy.dwellTime, const Duration(minutes: 2));
    });

    test('polygon round trip accepts integer coordinates', () {
      final p =
          Geofence.fromJson({
                'type': 'polygon',
                'id': 'p',
                'vertices': [
                  [0, 0],
                  [0, 1],
                  [1, 1],
                ],
              })
              as PolygonGeofence;
      expect(p.vertices, hasLength(3));
      expect(Geofence.fromJson(p.toJson()).toJson(), p.toJson());
    });

    test('unknown type throws', () {
      expect(() => Geofence.fromJson({'type': 'hexagon', 'id': 'x'}), throwsFormatException);
    });

    test('GeoPoint round trip', () {
      final p = GeoPoint(1.5, 2.5, accuracy: 12, time: t0);
      expect(GeoPoint.fromJson(p.toJson()), p);
    });
  });
}
