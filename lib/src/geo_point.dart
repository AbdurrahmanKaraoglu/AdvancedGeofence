/// A geographic position, optionally with the accuracy and time of the fix.
///
/// The same type is used for location readings (where [accuracy] and [time]
/// matter) and for geofence geometry (where only [latitude] and [longitude]
/// are used).
///
/// Adapt any location source to it, e.g. a `LocationDto` from
/// `advanced_background_locator`:
///
/// ```dart
/// GeoPoint(
///   dto.latitude,
///   dto.longitude,
///   accuracy: dto.accuracy,
///   time: DateTime.fromMillisecondsSinceEpoch(dto.time.toInt()),
/// );
/// ```
class GeoPoint {
  /// Creates a point. Coordinates are in degrees (WGS 84).
  const GeoPoint(this.latitude, this.longitude, {this.accuracy, this.time});

  /// Creates a point from [toJson] output.
  factory GeoPoint.fromJson(Map<String, Object?> json) {
    final time = json['time'];
    return GeoPoint(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      time: time is num ? DateTime.fromMillisecondsSinceEpoch(time.toInt(), isUtc: true) : null,
    );
  }

  /// Latitude in degrees, -90 to 90.
  final double latitude;

  /// Longitude in degrees. Values outside -180 to 180 are wrapped.
  final double longitude;

  /// Horizontal accuracy radius in meters (as reported by the platform).
  ///
  /// `null`, zero or negative means "unknown" and is treated as a perfect fix.
  final double? accuracy;

  /// When the fix was taken. `null` means "now" (the engine's clock).
  final DateTime? time;

  /// Whether the coordinates are finite and the latitude is within -90..90.
  bool get isValid => latitude.isFinite && longitude.isFinite && latitude >= -90 && latitude <= 90;

  /// JSON representation; [time] is milliseconds since epoch.
  Map<String, Object?> toJson() => {
    'lat': latitude,
    'lng': longitude,
    if (accuracy != null) 'accuracy': accuracy,
    if (time != null) 'time': time!.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracy == accuracy &&
      other.time == time;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy, time);

  @override
  String toString() =>
      'GeoPoint($latitude, $longitude${accuracy != null ? ', ±${accuracy}m' : ''}'
      '${time != null ? ', ${time!.toIso8601String()}' : ''})';
}
