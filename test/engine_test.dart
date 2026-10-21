import 'dart:convert';

import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const home = GeoPoint(41.0082, 28.9784);

/// A reading [north] meters north of [home] at second [sec].
GeoPoint r(double north, int sec, {double? acc}) => offset(home, north: north, time: at(sec), accuracy: acc);

GeofenceEngine engine({
  List<Geofence>? geofences,
  GeofenceOptions options = const GeofenceOptions(maxReadingAge: null),
  GeofenceEngineState? state,
}) => GeofenceEngine(
  geofences: geofences ?? [CircleGeofence(id: 'home', center: home, radius: 100)],
  options: options,
  state: state,
  clock: () => at(100000),
);

List<String> names(ProcessResult result) => [for (final e in result.events) '${e.type.name}:${e.geofenceId}'];

/// Feeds [readings] and returns all events.
List<GeofenceEvent> feed(GeofenceEngine e, Iterable<GeoPoint> readings) => [
  for (final p in readings) ...e.process(p).events,
];

void main() {
  group('enter and exit', () {
    test('outside → inside → outside', () {
      final e = engine();
      expect(feed(e, [r(300, 0), r(300, 1)]), isEmpty);
      expect(e.stateOf('home').status, GeofenceStatus.outside);

      expect(e.process(r(50, 10)).events, isEmpty, reason: 'needs 2 confirmations');
      final enter = e.process(r(40, 11)).events.single;
      expect(enter.type, GeofenceEventType.enter);
      expect(enter.initial, isFalse);
      expect(enter.since, at(10), reason: 'first reading of the confirming run');
      expect(enter.time, at(11));
      expect(enter.distance, closeTo(-60, 0.5));
      expect(e.insideGeofences.map((g) => g.id), ['home']);

      expect(e.process(r(300, 20)).events, isEmpty);
      final exit = e.process(r(300, 21)).events.single;
      expect(exit.type, GeofenceEventType.exit);
      expect(exit.since, at(20));
      expect(e.insideGeofences, isEmpty);
    });

    test('starting inside emits an initial enter', () {
      final e = engine();
      final events = feed(e, [r(0, 0), r(0, 1)]);
      expect(events.single.type, GeofenceEventType.enter);
      expect(events.single.initial, isTrue);
    });

    test('notifyInitialEnter: false starts inside silently but reports later entries', () {
      final e = engine(options: const GeofenceOptions(maxReadingAge: null, notifyInitialEnter: false));
      expect(feed(e, [r(0, 0), r(0, 1)]), isEmpty);
      expect(e.stateOf('home').status, GeofenceStatus.inside);
      expect(feed(e, [r(300, 2), r(300, 3)]).single.type, GeofenceEventType.exit);
      expect(feed(e, [r(0, 4), r(0, 5)]).single.type, GeofenceEventType.enter);
    });

    test('confirmations: 1 reacts to every clear reading', () {
      final e = engine(options: const GeofenceOptions(maxReadingAge: null, confirmations: 1, hysteresis: 0));
      expect(names(e.process(r(300, 0))), isEmpty);
      expect(names(e.process(r(50, 1))), ['enter:home']);
      expect(names(e.process(r(150, 2))), ['exit:home']);
    });

    test('polygon geofence', () {
      final square = PolygonGeofence(
        id: 'sq',
        vertices: [
          offset(home, north: -100, east: -100),
          offset(home, north: -100, east: 100),
          offset(home, north: 100, east: 100),
          offset(home, north: 100, east: -100),
        ],
      );
      final e = engine(geofences: [square]);
      feed(e, [r(500, 0), r(500, 1)]);
      expect(feed(e, [r(50, 2), r(50, 3)]).single.type, GeofenceEventType.enter);
      expect(feed(e, [r(150, 4), r(150, 5)]).single.type, GeofenceEventType.exit);
    });

    test('moving between adjacent geofences reports exit before enter', () {
      final e = engine(
        geofences: [
          CircleGeofence(id: 'b', center: offset(home, north: 300), radius: 100),
          CircleGeofence(id: 'a', center: home, radius: 100),
        ],
      );
      feed(e, [r(0, 0), r(0, 1)]);
      e.process(r(300, 2));
      expect(names(e.process(r(300, 3))), ['exit:a', 'enter:b']);
    });
  });

  group('noise', () {
    test('jitter across the boundary does not cause enter/exit storms once inside', () {
      final e = engine();
      feed(e, [r(0, 0), r(0, 1)]);
      final events = feed(e, [for (var i = 0; i < 40; i++) r(i.isEven ? 95 : 105, 2 + i)]);
      expect(events, isEmpty);
      expect(e.stateOf('home').status, GeofenceStatus.inside);
    });

    test('jitter across the boundary from outside never confirms an entry', () {
      final e = engine();
      feed(e, [r(300, 0), r(300, 1)]);
      final events = feed(e, [for (var i = 0; i < 40; i++) r(i.isEven ? 95 : 105, 2 + i)]);
      expect(events, isEmpty);
    });

    test('hysteresis: exit needs the boundary plus the buffer', () {
      final e = engine();
      feed(e, [r(0, 0), r(0, 1)]);
      expect(feed(e, [for (var i = 0; i < 5; i++) r(110, 2 + i)]), isEmpty, reason: '10 m out < 20 m buffer');
      expect(feed(e, [r(125, 10), r(125, 11)]).single.type, GeofenceEventType.exit);
    });

    test('a single GPS spike does not cause an exit', () {
      final e = engine();
      feed(e, [r(0, 0), r(0, 1)]);
      expect(feed(e, [r(1000, 2), r(0, 3), r(1000, 4), r(0, 5)]), isEmpty);
    });

    test('a reading confirming the current state resets a pending transition', () {
      final e = engine();
      feed(e, [r(300, 0), r(300, 1)]);
      expect(feed(e, [r(50, 2), r(300, 3), r(50, 4)]), isEmpty);
      expect(e.stateOf('home').pendingCount, 1);
      expect(feed(e, [r(50, 5)]).single.since, at(4));
    });

    test('ambiguous readings neither count nor reset a pending transition', () {
      final e = engine();
      feed(e, [r(300, 0), r(300, 1)]);
      e.process(r(50, 2));
      // 5 m inside with ±40 m accuracy (margin 20 m): ambiguous.
      expect(e.process(r(95, 3, acc: 40)).events, isEmpty);
      expect(e.stateOf('home').pendingCount, 1);
      final enter = e.process(r(50, 4)).events.single;
      expect(enter.since, at(2));
    });

    test('low accuracy readings are ignored', () {
      final e = engine();
      feed(e, [r(300, 0), r(300, 1)]);
      final result = e.process(r(0, 2, acc: 150));
      expect(result.accepted, isFalse);
      expect(result.ignoredReason, IgnoreReason.lowAccuracy);
      expect(feed(e, [r(0, 3, acc: 150), r(0, 4, acc: 101)]), isEmpty);
      expect(e.stateOf('home').status, GeofenceStatus.outside);
    });

    test('accuracy weight: a fix must be inside by part of its accuracy radius', () {
      final e = engine();
      feed(e, [r(300, 0), r(300, 1)]);
      // 30 m inside, ±80 m → margin 40 m: not convincing.
      expect(feed(e, [r(70, 2, acc: 80), r(70, 3, acc: 80)]), isEmpty);
      // 30 m inside, ±20 m → margin 10 m: inside.
      expect(feed(e, [r(70, 4, acc: 20), r(70, 5, acc: 20)]).single.type, GeofenceEventType.enter);
    });

    test('out-of-order and duplicate readings are ignored', () {
      final e = engine();
      expect(e.process(r(0, 10)).accepted, isTrue);
      expect(e.process(r(0, 5)).ignoredReason, IgnoreReason.outOfOrder);
      expect(e.process(r(0, 10)).ignoredReason, IgnoreReason.outOfOrder);
      expect(e.process(r(0, 11)).events.single.type, GeofenceEventType.enter);
    });

    test('stale readings are ignored', () {
      final e = GeofenceEngine(
        geofences: [CircleGeofence(id: 'home', center: home, radius: 100)],
        options: const GeofenceOptions(maxReadingAge: Duration(minutes: 1)),
        clock: () => at(600),
      );
      expect(e.process(r(0, 0)).ignoredReason, IgnoreReason.stale);
      expect(e.process(r(0, 1200)).ignoredReason, IgnoreReason.stale, reason: 'future fix');
      expect(e.process(r(0, 590)).accepted, isTrue);
    });

    test('invalid readings are ignored', () {
      final e = engine();
      expect(e.process(const GeoPoint(double.nan, 0)).ignoredReason, IgnoreReason.invalid);
      expect(e.process(const GeoPoint(95, 0)).ignoredReason, IgnoreReason.invalid);
    });

    test('readings without a time use the clock', () {
      final e = engine();
      expect(e.process(home).accepted, isTrue);
      expect(e.lastPoint!.time, at(100000));
      expect(e.process(home).ignoredReason, IgnoreReason.outOfOrder, reason: 'same clock time');
    });
  });

  group('dwell', () {
    GeofenceEngine dwellEngine() => engine(
      geofences: [CircleGeofence(id: 'home', center: home, radius: 100, dwellTime: const Duration(seconds: 60))],
    );

    test('fires once when the dwell time has passed since entry', () {
      final e = dwellEngine();
      feed(e, [r(300, 0), r(300, 1)]);
      expect(names(e.process(r(0, 10))), isEmpty);
      expect(names(e.process(r(0, 11))), ['enter:home']);
      expect(feed(e, [r(0, 30), r(0, 69)]), isEmpty);
      final dwell = e.process(r(0, 70)).events.single;
      expect(dwell.type, GeofenceEventType.dwell);
      expect(dwell.since, at(10));
      expect(feed(e, [r(0, 100), r(0, 500)]), isEmpty, reason: 'once per stay');
    });

    test('restarts after leaving and re-entering', () {
      final e = dwellEngine();
      feed(e, [r(0, 0), r(0, 1), r(0, 60)]);
      expect(names(e.process(r(300, 70))), isEmpty);
      expect(names(e.process(r(300, 71))), ['exit:home']);
      feed(e, [r(0, 200), r(0, 201)]);
      expect(feed(e, [r(0, 259)]), isEmpty);
      expect(names(e.process(r(0, 260))), ['dwell:home']);
    });

    test('an exit before the dwell time cancels the dwell', () {
      final e = dwellEngine();
      feed(e, [r(0, 0), r(0, 1), r(300, 30), r(300, 31)]);
      expect(feed(e, [r(300, 100), r(300, 200)]), isEmpty);
    });

    test('ambiguous readings while inside keep the dwell running', () {
      final e = dwellEngine();
      feed(e, [r(0, 0), r(0, 1)]);
      expect(names(e.process(r(110, 60))), ['dwell:home'], reason: 'still inside thanks to the hysteresis');
    });

    test('dwell and enter on the same reading come in that order', () {
      final e = engine(
        geofences: [CircleGeofence(id: 'home', center: home, radius: 100, dwellTime: Duration.zero)],
      );
      feed(e, [r(300, 0), r(300, 1), r(0, 2)]);
      expect(names(e.process(r(0, 3))), ['enter:home', 'dwell:home']);
    });

    test('defaultDwellTime applies to geofences without their own', () {
      final e = engine(options: const GeofenceOptions(maxReadingAge: null, defaultDwellTime: Duration(seconds: 30)));
      feed(e, [r(0, 0), r(0, 1)]);
      expect(names(e.process(r(0, 30))), ['dwell:home']);
    });

    test('advanceTime emits due dwell events without new readings', () {
      final e = dwellEngine();
      expect(e.advanceTime(at(0)), isEmpty, reason: 'no readings yet');
      feed(e, [r(0, 0), r(0, 1)]);
      expect(e.advanceTime(at(59)), isEmpty);
      final events = e.advanceTime(at(60));
      expect(events.single.type, GeofenceEventType.dwell);
      expect(events.single.time, at(60));
      expect(e.advanceTime(at(120)), isEmpty);
      expect(e.process(r(0, 130)).events, isEmpty);
    });
  });

  group('state', () {
    GeofenceEngineState roundTrip(GeofenceEngine e) =>
        GeofenceEngineState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, Object?>);

    test('a restored engine continues without duplicate events', () {
      final a = engine();
      feed(a, [r(0, 0), r(0, 1)]);
      final b = engine(state: roundTrip(a));
      expect(b.stateOf('home').status, GeofenceStatus.inside);
      expect(b.stateOf('home').since, at(0));
      expect(feed(b, [r(0, 2), r(0, 3)]), isEmpty, reason: 'no second enter');
      expect(b.process(r(0, 1)).ignoredReason, IgnoreReason.outOfOrder, reason: 'last time restored');
      expect(names(b.process(r(300, 4))), isEmpty);
      expect(names(b.process(r(300, 5))), ['exit:home']);
    });

    test('pending confirmations and dwell flags survive a restart', () {
      final a = engine(
        geofences: [CircleGeofence(id: 'home', center: home, radius: 100, dwellTime: const Duration(seconds: 10))],
      );
      feed(a, [r(0, 0), r(0, 1), r(0, 20), r(300, 21)]);
      expect(a.stateOf('home').dwellNotified, isTrue);
      expect(a.stateOf('home').pendingCount, 1);
      final b = engine(
        geofences: [CircleGeofence(id: 'home', center: home, radius: 100, dwellTime: const Duration(seconds: 10))],
        state: roundTrip(a),
      );
      final exit = b.process(r(300, 22)).events.single;
      expect(exit.type, GeofenceEventType.exit);
      expect(exit.since, at(21));
    });

    test('state only includes current geofences and ignores unknown ids', () {
      final a = engine(
        geofences: [
          CircleGeofence(id: 'home', center: home, radius: 100),
          CircleGeofence(id: 'old', center: offset(home, north: 5000), radius: 100),
        ],
      );
      feed(a, [r(0, 0), r(0, 1)]);
      final b = engine(state: roundTrip(a));
      expect(b.state.regions.keys, ['home']);
    });

    test('unsupported state versions throw', () {
      expect(() => GeofenceEngineState.fromJson({'version': 99}), throwsFormatException);
    });

    test('removeGeofence forgets the state without an exit', () {
      final e = engine();
      feed(e, [r(0, 0), r(0, 1)]);
      e.removeGeofence('home');
      expect(e.insideGeofences, isEmpty);
      expect(feed(e, [r(300, 2), r(300, 3)]), isEmpty);
      expect(e.stateOf('home').status, GeofenceStatus.unknown);
    });

    test('resetState makes a geofence unknown again', () {
      final e = engine();
      feed(e, [r(0, 0), r(0, 1)]);
      e.resetState('home');
      final events = feed(e, [r(0, 2), r(0, 3)]);
      expect(events.single.initial, isTrue);
    });

    test('events survive a JSON round trip', () {
      final e = engine();
      final event = feed(e, [r(0, 0), r(0, 1)]).single;
      final copy = GeofenceEvent.fromJson(jsonDecode(jsonEncode(event.toJson())) as Map<String, Object?>);
      expect(copy.type, event.type);
      expect(copy.geofenceId, 'home');
      expect(copy.time, event.time);
      expect(copy.since, event.since);
      expect(copy.initial, isTrue);
      expect(copy.point.latitude, event.point.latitude);
      expect((copy.geofence as CircleGeofence).radius, 100);
    });
  });

  group('many geofences', () {
    // A 50 x 50 grid of 2500 circles, ~1.1 km apart, around Istanbul.
    final fences = [
      for (var i = 0; i < 50; i++)
        for (var j = 0; j < 50; j++)
          CircleGeofence(id: 'g$i-$j', center: GeoPoint(40.75 + i * 0.01, 28.75 + j * 0.01), radius: 150),
    ];
    // A walk crossing the grid diagonally, one reading every 5 s.
    final walk = [
      for (var k = 0; k < 600; k++) GeoPoint(40.75 + k * 0.0008, 28.75 + k * 0.0007, accuracy: 10, time: at(k * 5)),
    ];

    test('the grid index matches a brute-force engine', () {
      final indexed = engine(geofences: fences);
      final brute = engine(
        geofences: fences,
        options: const GeofenceOptions(maxReadingAge: null, gridCellDegrees: 360),
      );
      final a = feed(indexed, walk).map((e) => '${e.type.name}:${e.geofenceId}@${e.time}').toList();
      final b = feed(brute, walk).map((e) => '${e.type.name}:${e.geofenceId}@${e.time}').toList();
      expect(a, isNotEmpty);
      expect(a, b);
    });

    test('only nearby geofences are evaluated once states are known', () {
      final e = engine(geofences: fences);
      expect(e.process(walk[0]).evaluated, 2500, reason: 'all start unknown');
      e.process(walk[1]);
      for (final p in walk.skip(2)) {
        expect(e.process(p).evaluated, lessThan(10));
      }
    });
  });

  test('monitor turns a reading stream into an event stream', () async {
    final e = engine();
    final events = await e.monitor(Stream.fromIterable([r(300, 0), r(300, 1), r(0, 2), r(0, 3)])).toList();
    expect(events.single.type, GeofenceEventType.enter);
  });

  test('invalid options throw', () {
    expect(() => engine(options: const GeofenceOptions(confirmations: 0)), throwsArgumentError);
    expect(() => engine(options: const GeofenceOptions(hysteresis: -1)), throwsArgumentError);
  });
}
