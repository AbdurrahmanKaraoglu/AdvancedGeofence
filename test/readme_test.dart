// Keeps the README examples compiling and behaving as described.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('Usage', () async {
    final engine = GeofenceEngine(
      geofences: [
        CircleGeofence(
          id: 'office',
          name: 'Office',
          center: const GeoPoint(41.0082, 28.9784),
          radius: 150,
          dwellTime: const Duration(minutes: 5),
        ),
        PolygonGeofence(
          id: 'campus',
          vertices: const [
            GeoPoint(41.010, 28.970),
            GeoPoint(41.010, 28.985),
            GeoPoint(41.002, 28.985),
            GeoPoint(41.002, 28.970),
          ],
        ),
      ],
      options: const GeofenceOptions(maxReadingAge: null),
    );

    final seen = <String>[];
    for (final (lat, lng, accuracy, time) in [(41.0082, 28.9784, 10.0, at(0)), (41.0082, 28.9784, 10.0, at(5))]) {
      final result = engine.process(GeoPoint(lat, lng, accuracy: accuracy, time: time));
      for (final event in result.events) {
        seen.add('${event.type.name} ${event.geofence.name ?? event.geofenceId}');
      }
      expect(result.accepted, isTrue);
    }
    expect(seen, ['enter Office', 'enter campus']);

    final readings = StreamController<GeoPoint>();
    final events = engine.monitor(readings.stream).toList();
    readings.add(offset(const GeoPoint(41.0082, 28.9784), north: 2000, time: at(10)));
    readings.add(offset(const GeoPoint(41.0082, 28.9784), north: 2000, time: at(11)));
    await readings.close();
    expect((await events).map((e) => e.type), [GeofenceEventType.exit, GeofenceEventType.exit]);
  });

  test('Saving and restoring state', () async {
    final dir = await Directory.systemTemp.createTemp('advanced_geofence');
    addTearDown(() => dir.delete(recursive: true));
    final stateFile = File('${dir.path}/state.json');
    final geofences = [CircleGeofence(id: 'office', center: const GeoPoint(41.0082, 28.9784), radius: 150)];

    final first = GeofenceEngine(geofences: geofences, options: const GeofenceOptions(maxReadingAge: null));
    first.process(GeoPoint(41.0082, 28.9784, time: at(0)));
    first.process(GeoPoint(41.0082, 28.9784, time: at(1)));
    await stateFile.writeAsString(jsonEncode(first.state.toJson()));

    Future<GeofenceEngine> restore() async {
      GeofenceEngineState? saved;
      try {
        saved = GeofenceEngineState.fromJson(jsonDecode(await stateFile.readAsString()));
      } on FormatException {
        saved = null; // damaged or unknown data: start fresh
      }
      return GeofenceEngine(geofences: geofences, state: saved);
    }

    expect((await restore()).stateOf('office').status, GeofenceStatus.inside);

    await stateFile.writeAsString('{"version": 1, "regions": [');
    expect((await restore()).stateOf('office').status, GeofenceStatus.unknown);
  });
}
