import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:test/test.dart';

void main() {
  test('returns only geofences of the cell', () {
    final index = GeofenceIndex(cellDegrees: 0.1);
    index.add(CircleGeofence(id: 'a', center: const GeoPoint(41, 29), radius: 100));
    index.add(CircleGeofence(id: 'b', center: const GeoPoint(39.9, 32.8), radius: 100));
    expect(index.candidates(41, 29).map((g) => g.id), ['a']);
    expect(index.candidates(39.9, 32.8).map((g) => g.id), ['b']);
    expect(index.candidates(0, 0), isEmpty);
  });

  test('a geofence spanning cells is found from each of them', () {
    final index = GeofenceIndex(cellDegrees: 0.01);
    index.add(CircleGeofence(id: 'big', center: const GeoPoint(41, 29), radius: 3000));
    expect(index.candidates(41.02, 29.02).map((g) => g.id), ['big']);
    expect(index.candidates(40.98, 28.98).map((g) => g.id), ['big']);
  });

  test('antimeridian geofences are found on both sides', () {
    final index = GeofenceIndex();
    index.add(CircleGeofence(id: 'am', center: const GeoPoint(0, 180), radius: 2000));
    expect(index.candidates(0, 179.99).map((g) => g.id), ['am']);
    expect(index.candidates(0, -179.99).map((g) => g.id), ['am']);
  });

  test('huge geofences are always candidates', () {
    final index = GeofenceIndex(cellDegrees: 0.01, maxCellsPerGeofence: 100);
    index.add(CircleGeofence(id: 'country', center: const GeoPoint(39, 35), radius: 500000));
    expect(index.candidates(-50, -50).map((g) => g.id), ['country']);
  });

  test('remove and replace', () {
    final index = GeofenceIndex();
    index.add(CircleGeofence(id: 'a', center: const GeoPoint(41, 29), radius: 100));
    index.add(CircleGeofence(id: 'a', center: const GeoPoint(10, 10), radius: 100));
    expect(index.candidates(41, 29), isEmpty);
    expect(index.candidates(10, 10).map((g) => g.id), ['a']);
    index.remove('a');
    expect(index.candidates(10, 10), isEmpty);
  });

  test('rejects bad cell sizes', () {
    expect(() => GeofenceIndex(cellDegrees: 0), throwsArgumentError);
  });
}
