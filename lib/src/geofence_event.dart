import 'geo_point.dart';
import 'geofence.dart';

/// The kind of a [GeofenceEvent].
enum GeofenceEventType {
  /// The device entered the geofence.
  enter,

  /// The device left the geofence.
  exit,

  /// The device has stayed inside the geofence for its dwell time.
  dwell,
}

/// A transition produced by a `GeofenceEngine`.
class GeofenceEvent {
  /// Creates an event.
  const GeofenceEvent({
    required this.type,
    required this.geofence,
    required this.point,
    required this.time,
    required this.since,
    required this.distance,
    this.initial = false,
  });

  /// Recreates an event from [toJson] output, e.g. after it was sent to the
  /// UI isolate through a `SendPort`.
  factory GeofenceEvent.fromJson(Map<String, Object?> json) => GeofenceEvent(
    type: GeofenceEventType.values.byName(json['type'] as String),
    geofence: Geofence.fromJson((json['geofence'] as Map).cast<String, Object?>()),
    point: GeoPoint.fromJson((json['point'] as Map).cast<String, Object?>()),
    time: DateTime.fromMillisecondsSinceEpoch((json['time'] as num).toInt(), isUtc: true),
    since: DateTime.fromMillisecondsSinceEpoch((json['since'] as num).toInt(), isUtc: true),
    distance: (json['distance'] as num).toDouble(),
    initial: json['initial'] == true,
  );

  /// What happened.
  final GeofenceEventType type;

  /// The geofence concerned.
  final Geofence geofence;

  /// The reading that triggered the event (for dwell events produced by
  /// `GeofenceEngine.advanceTime`, the last accepted reading).
  final GeoPoint point;

  /// When the event was decided: the time of the triggering reading, or the
  /// time passed to `advanceTime`.
  final DateTime time;

  /// When the new state began. For `enter`/`exit` this is the first reading of
  /// the confirming run (the actual crossing is between that reading and the
  /// one before it); for `dwell` it is the time of entry.
  final DateTime since;

  /// Signed distance to the boundary in meters at [point] (negative inside).
  final double distance;

  /// Whether this `enter` was found on the very first readings, i.e. the
  /// device was already inside when monitoring started.
  final bool initial;

  /// Shortcut for `geofence.id`.
  String get geofenceId => geofence.id;

  /// JSON representation (only JSON-encodable values, safe for `SendPort`).
  Map<String, Object?> toJson() => {
    'type': type.name,
    'geofence': geofence.toJson(),
    'point': point.toJson(),
    'time': time.millisecondsSinceEpoch,
    'since': since.millisecondsSinceEpoch,
    'distance': distance,
    if (initial) 'initial': true,
  };

  @override
  String toString() =>
      'GeofenceEvent(${type.name}${initial ? ' (initial)' : ''}, ${geofence.id}, ${time.toIso8601String()})';
}
