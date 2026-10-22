import 'geo_point.dart';
import 'json_util.dart';

/// Where the device is relative to one geofence.
enum GeofenceStatus {
  /// Not decided yet (no or not enough clear readings).
  unknown,

  /// Inside the geofence.
  inside,

  /// Outside the geofence.
  outside,
}

/// The state of a single geofence.
class GeofenceRegionState {
  /// Creates a state.
  const GeofenceRegionState({
    this.status = GeofenceStatus.unknown,
    this.since,
    this.dwellNotified = false,
    this.pendingStatus,
    this.pendingCount = 0,
    this.pendingSince,
  });

  /// Recreates a state from [toJson] output.
  ///
  /// Throws a [FormatException] if [json] is malformed.
  factory GeofenceRegionState.fromJson(Map<String, Object?> json) => parseJson(
    'geofence region state',
    () => GeofenceRegionState(
      status: GeofenceStatus.values.byName(json['status'] as String? ?? 'unknown'),
      since: _time(json['since']),
      dwellNotified: json['dwellNotified'] == true,
      pendingStatus: json['pendingStatus'] == null
          ? null
          : GeofenceStatus.values.byName(json['pendingStatus'] as String),
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      pendingSince: _time(json['pendingSince']),
    ),
  );

  /// The confirmed status.
  final GeofenceStatus status;

  /// When [status] began (the first reading of the confirming run).
  final DateTime? since;

  /// Whether a dwell event was already emitted for the current stay.
  final bool dwellNotified;

  /// The status that recent readings point to but that is not confirmed yet.
  final GeofenceStatus? pendingStatus;

  /// How many consecutive readings agreed with [pendingStatus].
  final int pendingCount;

  /// Time of the first reading that agreed with [pendingStatus].
  final DateTime? pendingSince;

  /// Whether the engine has to keep evaluating this geofence even when the
  /// device is far away from it.
  bool get needsTracking => status != GeofenceStatus.outside || pendingCount > 0;

  /// JSON representation; times are milliseconds since epoch.
  Map<String, Object?> toJson() => {
    'status': status.name,
    if (since != null) 'since': since!.millisecondsSinceEpoch,
    if (dwellNotified) 'dwellNotified': true,
    if (pendingStatus != null) 'pendingStatus': pendingStatus!.name,
    if (pendingCount != 0) 'pendingCount': pendingCount,
    if (pendingSince != null) 'pendingSince': pendingSince!.millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'GeofenceRegionState(${status.name}'
      '${pendingStatus != null ? ', pending ${pendingStatus!.name} x$pendingCount' : ''})';
}

/// Everything a `GeofenceEngine` needs to resume where it stopped.
///
/// Save [toJson] (e.g. with `jsonEncode` to a file) after each processed
/// reading and pass [GeofenceEngineState.fromJson] to the engine when the
/// background isolate starts again.
class GeofenceEngineState {
  /// Creates a state.
  const GeofenceEngineState({this.lastPoint, this.regions = const {}});

  /// Recreates a state from [toJson] output.
  ///
  /// Malformed input and unknown versions throw a [FormatException], so a
  /// damaged file can be caught and monitoring started fresh. Later versions
  /// of this package keep reading states written by earlier ones.
  factory GeofenceEngineState.fromJson(Map<String, Object?> json) => parseJson('geofence state', () {
    final version = json['version'];
    if (version != _version) {
      throw FormatException('Unsupported geofence state version: $version');
    }
    final last = json['lastPoint'] as Map?;
    final regions = (json['regions'] as Map?) ?? const {};
    return GeofenceEngineState(
      lastPoint: last == null ? null : GeoPoint.fromJson(last.cast<String, Object?>()),
      regions: {
        for (final entry in regions.entries)
          entry.key as String: GeofenceRegionState.fromJson((entry.value as Map).cast<String, Object?>()),
      },
    );
  });

  static const int _version = 1;

  /// The last accepted reading (always with a time).
  final GeoPoint? lastPoint;

  /// Per-geofence state, keyed by geofence id.
  final Map<String, GeofenceRegionState> regions;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'version': _version,
    if (lastPoint != null) 'lastPoint': lastPoint!.toJson(),
    'regions': {for (final e in regions.entries) e.key: e.value.toJson()},
  };
}

DateTime? _time(Object? value) => value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true) : null;
