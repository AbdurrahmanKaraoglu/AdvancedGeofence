import 'dart:math' as math;

import 'geo_math.dart';
import 'geo_point.dart';
import 'geofence.dart';
import 'geofence_event.dart';
import 'geofence_index.dart';
import 'geofence_options.dart';
import 'geofence_state.dart';

/// Why a reading was not used. See [ProcessResult.ignoredReason].
enum IgnoreReason {
  /// NaN/infinite coordinates or a latitude outside -90..90.
  invalid,

  /// Not newer than the last accepted reading (out of order or duplicate).
  outOfOrder,

  /// Further than [GeofenceOptions.maxReadingAge] from the engine clock
  /// (too old, or in the future).
  stale,

  /// Accuracy radius above [GeofenceOptions.maxAccuracy].
  lowAccuracy,
}

/// The outcome of [GeofenceEngine.process].
class ProcessResult {
  /// Creates a result.
  const ProcessResult({this.events = const [], this.ignoredReason, this.evaluated = 0});

  /// Events produced by the reading, ordered exit → enter → dwell.
  final List<GeofenceEvent> events;

  /// Why the reading was ignored, or `null` when it was used.
  final IgnoreReason? ignoredReason;

  /// How many geofences were evaluated geometrically (useful to check that
  /// the spatial pre-filter works).
  final int evaluated;

  /// Whether the reading was used.
  bool get accepted => ignoredReason == null;
}

/// Turns a stream of location readings into geofence enter/exit/dwell events.
///
/// The engine is pure Dart and synchronous: it does not read the location
/// itself, start timers or touch storage, so it works in any isolate
/// (including a background location callback) and with any location source.
///
/// ```dart
/// final engine = GeofenceEngine(geofences: [
///   CircleGeofence(id: 'office', center: const GeoPoint(41.0082, 28.9784), radius: 150),
/// ]);
/// for (final event in engine.process(reading).events) {
///   print('${event.type.name} ${event.geofenceId}');
/// }
/// final saved = engine.state.toJson(); // persist, then restore with `state:`
/// ```
class GeofenceEngine {
  /// Creates an engine.
  ///
  /// [state] restores a previous [GeofenceEngine.state]; states are matched to
  /// geofences by id. [clock] is used for readings without a time and for
  /// [GeofenceOptions.maxReadingAge].
  GeofenceEngine({
    Iterable<Geofence> geofences = const [],
    this.options = const GeofenceOptions(),
    GeofenceEngineState? state,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _index = GeofenceIndex(cellDegrees: options.gridCellDegrees) {
    if (options.confirmations < 1) {
      throw ArgumentError.value(options.confirmations, 'confirmations', 'must be at least 1');
    }
    if (options.hysteresis.isNaN || options.hysteresis < 0) {
      throw ArgumentError.value(options.hysteresis, 'hysteresis', 'must not be negative');
    }
    if (options.accuracyWeight.isNaN || options.accuracyWeight < 0) {
      throw ArgumentError.value(options.accuracyWeight, 'accuracyWeight', 'must not be negative');
    }
    if (state != null) {
      _lastPoint = state.lastPoint;
      _states.addAll(state.regions);
    }
    for (final g in geofences) {
      addGeofence(g);
    }
  }

  /// The noise filter settings.
  final GeofenceOptions options;

  final DateTime Function() _clock;
  final GeofenceIndex _index;
  final Map<String, Geofence> _geofences = {};
  final Map<String, GeofenceRegionState> _states = {};

  /// Ids of geofences that must be evaluated on every reading (inside,
  /// unknown or with a pending transition).
  final Set<String> _tracked = {};
  GeoPoint? _lastPoint;

  /// The monitored geofences.
  Iterable<Geofence> get geofences => _geofences.values;

  /// The geofence with [id], or `null`.
  Geofence? geofence(String id) => _geofences[id];

  /// The last accepted reading.
  GeoPoint? get lastPoint => _lastPoint;

  /// The geofences the device is currently (confirmed) inside.
  List<Geofence> get insideGeofences => [
    for (final id in _tracked)
      if (_states[id]?.status == GeofenceStatus.inside) _geofences[id]!,
  ];

  /// The state of the geofence with [id]. Unknown ids report
  /// [GeofenceStatus.unknown].
  GeofenceRegionState stateOf(String id) => _states[id] ?? const GeofenceRegionState();

  /// A snapshot of the whole state, to persist with
  /// `jsonEncode(engine.state.toJson())`.
  GeofenceEngineState get state =>
      GeofenceEngineState(lastPoint: _lastPoint, regions: {for (final id in _geofences.keys) id: ?_states[id]});

  /// Adds [geofence] or replaces the geofence with the same id.
  ///
  /// A replaced (or restored) geofence keeps its state; call [resetState] if
  /// its geometry changed a lot.
  void addGeofence(Geofence geofence) {
    _geofences[geofence.id] = geofence;
    _index.add(geofence);
    _updateTracking(geofence.id, stateOf(geofence.id));
  }

  /// Adds or replaces several geofences.
  void addGeofences(Iterable<Geofence> geofences) => geofences.forEach(addGeofence);

  /// Stops monitoring the geofence with [id] and forgets its state. No exit
  /// event is emitted.
  void removeGeofence(String id) {
    _geofences.remove(id);
    _index.remove(id);
    _states.remove(id);
    _tracked.remove(id);
  }

  /// Removes every geofence and all state.
  void clear() {
    for (final id in _geofences.keys.toList()) {
      removeGeofence(id);
    }
    _states.clear();
    _lastPoint = null;
  }

  /// Forgets the state of the geofence with [id] (it becomes unknown).
  void resetState(String id) {
    _states.remove(id);
    if (_geofences.containsKey(id)) _tracked.add(id);
  }

  /// Feeds one location reading and returns the resulting events.
  ProcessResult process(GeoPoint reading) {
    if (!reading.isValid) return const ProcessResult(ignoredReason: IgnoreReason.invalid);
    final now = _clock();
    final time = reading.time ?? now;
    final maxAge = options.maxReadingAge;
    final last = _lastPoint?.time;
    // A last reading far in the future of the clock (restored state after the
    // device clock was set back) is not trusted, or nothing would be accepted.
    final lastTrusted = last != null && (maxAge == null || !last.isAfter(now.add(maxAge)));
    if (lastTrusted && !time.isAfter(last)) {
      return const ProcessResult(ignoredReason: IgnoreReason.outOfOrder);
    }
    // Also rejects fixes from the future (a wrong device clock), which would
    // otherwise make every later reading look out of order.
    if (maxAge != null && now.difference(time).abs() > maxAge) {
      return const ProcessResult(ignoredReason: IgnoreReason.stale);
    }
    final accuracy = reading.accuracy;
    if (accuracy != null && accuracy > options.maxAccuracy) {
      return const ProcessResult(ignoredReason: IgnoreReason.lowAccuracy);
    }

    final point = GeoPoint(
      reading.latitude,
      normalizeLongitude(reading.longitude),
      accuracy: reading.accuracy,
      time: time,
    );
    _lastPoint = point;
    final margin = math.max(0.0, accuracy ?? 0) * options.accuracyWeight;

    final events = <GeofenceEvent>[];
    final tracked = _tracked.toList();
    final trackedIds = tracked.toSet();
    var evaluated = 0;
    for (final g in _index.candidates(point.latitude, point.longitude)) {
      // Tracked geofences are evaluated below; untouched outside geofences
      // only matter when the point is inside their bounding box.
      if (trackedIds.contains(g.id) || !g.bounds.containsLatLng(point.latitude, point.longitude)) {
        continue;
      }
      evaluated++;
      _evaluate(g, point, margin, events);
    }
    for (final id in tracked) {
      evaluated++;
      _evaluate(_geofences[id]!, point, margin, events);
    }
    // Exits first, so moving between adjacent geofences reads naturally.
    return ProcessResult(
      events: [
        for (final type in const [GeofenceEventType.exit, GeofenceEventType.enter, GeofenceEventType.dwell])
          ...events.where((e) => e.type == type),
      ],
      evaluated: evaluated,
    );
  }

  /// Emits dwell events that are due at [now] without a new reading.
  ///
  /// Readings normally drive dwell detection; call this from a timer if
  /// readings can be sparse (e.g. a stationary device with a distance filter).
  List<GeofenceEvent> advanceTime([DateTime? now]) {
    final point = _lastPoint;
    if (point == null) return const [];
    final time = now ?? _clock();
    final events = <GeofenceEvent>[];
    for (final id in _tracked) {
      final s = _states[id];
      if (s == null || s.status != GeofenceStatus.inside) continue;
      final g = _geofences[id]!;
      final dwell = _dwellEvent(g, s, point, time, g.signedDistance(point));
      if (dwell != null) {
        events.add(dwell);
        _states[id] = _copy(s, dwellNotified: true);
      }
    }
    return events;
  }

  /// Processes every reading of [readings] and emits the resulting events.
  Stream<GeofenceEvent> monitor(Stream<GeoPoint> readings) => readings.expand((reading) => process(reading).events);

  void _evaluate(Geofence g, GeoPoint point, double margin, List<GeofenceEvent> events) {
    var s = stateOf(g.id);
    final time = point.time!;
    final distance = g.signedDistance(point);

    final GeofenceStatus? observed;
    if (distance <= -margin) {
      observed = GeofenceStatus.inside;
    } else if (distance >= margin + (s.status == GeofenceStatus.inside ? options.hysteresis : 0)) {
      observed = GeofenceStatus.outside;
    } else {
      observed = null; // ambiguous: within the uncertainty/hysteresis band
    }

    if (observed == s.status) {
      if (s.pendingCount > 0) s = _copy(s, clearPending: true);
    } else if (observed != null) {
      final count = s.pendingStatus == observed ? s.pendingCount + 1 : 1;
      final pendingSince = s.pendingStatus == observed ? s.pendingSince ?? time : time;
      if (count >= options.confirmations) {
        final previous = s.status;
        s = GeofenceRegionState(status: observed, since: pendingSince);
        if (observed == GeofenceStatus.inside && (previous == GeofenceStatus.outside || options.notifyInitialEnter)) {
          events.add(
            GeofenceEvent(
              type: GeofenceEventType.enter,
              geofence: g,
              point: point,
              time: time,
              since: pendingSince,
              distance: distance,
              initial: previous == GeofenceStatus.unknown,
            ),
          );
        } else if (observed == GeofenceStatus.outside && previous == GeofenceStatus.inside) {
          events.add(
            GeofenceEvent(
              type: GeofenceEventType.exit,
              geofence: g,
              point: point,
              time: time,
              since: pendingSince,
              distance: distance,
            ),
          );
        }
      } else {
        s = GeofenceRegionState(
          status: s.status,
          since: s.since,
          dwellNotified: s.dwellNotified,
          pendingStatus: observed,
          pendingCount: count,
          pendingSince: pendingSince,
        );
      }
    }

    if (s.status == GeofenceStatus.inside) {
      final dwell = _dwellEvent(g, s, point, time, distance);
      if (dwell != null) {
        events.add(dwell);
        s = _copy(s, dwellNotified: true);
      }
    }
    _states[g.id] = s;
    _updateTracking(g.id, s);
  }

  GeofenceEvent? _dwellEvent(Geofence g, GeofenceRegionState s, GeoPoint point, DateTime time, double distance) {
    final dwellTime = g.dwellTime ?? options.defaultDwellTime;
    final since = s.since;
    if (dwellTime == null || s.dwellNotified || since == null) return null;
    // Wait while an exit is being confirmed: the device may already have left.
    if (s.pendingStatus == GeofenceStatus.outside && s.pendingCount > 0) return null;
    if (time.difference(since) < dwellTime) return null;
    return GeofenceEvent(
      type: GeofenceEventType.dwell,
      geofence: g,
      point: point,
      time: time,
      since: since,
      distance: distance,
    );
  }

  void _updateTracking(String id, GeofenceRegionState s) {
    if (s.needsTracking) {
      _tracked.add(id);
    } else {
      _tracked.remove(id);
    }
  }

  static GeofenceRegionState _copy(GeofenceRegionState s, {bool? dwellNotified, bool clearPending = false}) =>
      GeofenceRegionState(
        status: s.status,
        since: s.since,
        dwellNotified: dwellNotified ?? s.dwellNotified,
        pendingStatus: clearPending ? null : s.pendingStatus,
        pendingCount: clearPending ? 0 : s.pendingCount,
        pendingSince: clearPending ? null : s.pendingSince,
      );
}
