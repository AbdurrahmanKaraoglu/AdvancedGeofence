// End-to-end check with simulated, noisy GPS from route_simulator (a dev
// dependency only). route_simulator has its own GeoPoint, hence the prefix.
import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:route_simulator/route_simulator.dart' as sim;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const center = GeoPoint(41.0082, 28.9784);
  final south = offset(center, north: -400);
  final north = offset(center, north: 400);

  /// Walks south → center (waits 2 min) → north at 1.4 m/s and returns the
  /// events of a 100 m circle around the center.
  List<GeofenceEvent> walk(int seed, {required Duration dwellTime}) {
    final simulator = sim.RouteSimulator(
      route: sim.SimRoute([
        sim.GeoPoint(south.latitude, south.longitude),
        sim.GeoPoint(center.latitude, center.longitude),
        sim.GeoPoint(north.latitude, north.longitude),
      ]),
      profile: const sim.SpeedProfile.constant(1.4),
      stops: const [sim.RouteStop.atPoint(1, Duration(minutes: 2))],
      noise: sim.GpsNoise(
        horizontalError: 4,
        jumpProbability: 0.02,
        jumpDistance: 40,
        dropoutProbability: 0.02,
        seed: seed,
      ),
      startTime: t0,
    );
    final engine = GeofenceEngine(
      geofences: [CircleGeofence(id: 'park', center: center, radius: 100, dwellTime: dwellTime)],
      options: const GeofenceOptions(maxReadingAge: null), // recorded timestamps
    );
    return [
      for (final l in simulator.generate())
        ...engine.process(GeoPoint(l.latitude, l.longitude, accuracy: l.accuracy, time: l.time)).events,
    ];
  }

  test('noisy walks through a geofence give exactly enter, dwell, exit', () {
    for (var seed = 0; seed < 25; seed++) {
      final events = walk(seed, dwellTime: const Duration(minutes: 1));
      expect(events.map((e) => e.type), [
        GeofenceEventType.enter,
        GeofenceEventType.dwell,
        GeofenceEventType.exit,
      ], reason: 'seed $seed');
      // The boundary is 300 m from the start: reached after ~214 s.
      expect(events.first.since.difference(t0).inSeconds, inInclusiveRange(200, 235), reason: 'seed $seed');
      // Leaving: 214 s + 71 s to the center + 120 s stop + 71 s to the boundary ≈ 477 s, plus the hysteresis.
      expect(events.last.since.difference(t0).inSeconds, inInclusiveRange(470, 510), reason: 'seed $seed');
    }
  });

  test('a visit shorter than the dwell time gives no dwell', () {
    // About 4.4 minutes inside.
    final events = walk(7, dwellTime: const Duration(minutes: 5));
    expect(events.map((e) => e.type), [GeofenceEventType.enter, GeofenceEventType.exit]);
  });
}
