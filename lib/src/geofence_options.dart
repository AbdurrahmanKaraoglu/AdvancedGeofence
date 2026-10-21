/// Tuning for the noise filters of a `GeofenceEngine`.
///
/// The defaults suit phone GPS readings and geofences with a radius of about
/// 50 m or more.
class GeofenceOptions {
  /// Creates options. See each field for its meaning.
  const GeofenceOptions({
    this.hysteresis = 20,
    this.confirmations = 2,
    this.maxAccuracy = 100,
    this.accuracyWeight = 0.5,
    this.maxReadingAge = const Duration(minutes: 5),
    this.notifyInitialEnter = true,
    this.defaultDwellTime,
    this.gridCellDegrees = 0.05,
  });

  /// Extra distance in meters, beyond the boundary, before an *exit* is
  /// accepted.
  ///
  /// Once inside, the geofence effectively grows by this much, so a reading
  /// jittering around the boundary does not produce enter/exit storms.
  final double hysteresis;

  /// How many consecutive readings must agree before a transition is
  /// accepted. `1` reacts to every reading.
  ///
  /// Ambiguous readings (inside the hysteresis or uncertainty band) neither
  /// count towards nor reset a pending transition; a reading that confirms
  /// the current state resets it.
  final int confirmations;

  /// Readings with an accuracy radius above this many meters are ignored.
  /// Use `double.infinity` to accept all readings.
  final double maxAccuracy;

  /// Share of a reading's accuracy radius that must lie on the far side of
  /// the boundary for the reading to count.
  ///
  /// With `0.5` and a ±40 m reading, the point must be at least 20 m inside
  /// to count as "inside" (and 20 m + [hysteresis] outside to count as
  /// "outside"). `0` uses the raw position, `1` requires the whole accuracy
  /// circle to be on one side.
  final double accuracyWeight;

  /// Readings older than this (compared with the engine clock) are ignored,
  /// e.g. a cached last-known location delivered when tracking starts.
  /// Readings this far in the future are ignored too (wrong device clock).
  /// `null` disables the check, which is needed when replaying recorded or
  /// simulated routes with old timestamps.
  final Duration? maxReadingAge;

  /// Whether a geofence that the very first readings find the device inside
  /// emits an `enter` event (marked with `GeofenceEvent.initial`).
  ///
  /// When `false` such geofences silently start as inside, like an OS
  /// geofence registered without an initial trigger.
  final bool notifyInitialEnter;

  /// Dwell time for geofences that do not set their own `dwellTime`.
  /// `null` disables dwell events for them.
  final Duration? defaultDwellTime;

  /// Cell size in degrees of the spatial grid used to pre-filter geofences.
  /// `0.05` is about 5.5 km in latitude.
  final double gridCellDegrees;
}
