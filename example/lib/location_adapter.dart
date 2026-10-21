import 'package:advanced_background_locator/advanced_background_locator.dart';
import 'package:advanced_geofence/advanced_geofence.dart';

/// Adapts advanced_background_locator readings to advanced_geofence.
///
/// advanced_geofence has no dependency on any location plugin; a small
/// adapter like this is all that is needed.
extension LocationDtoToGeoPoint on LocationDto {
  GeoPoint toGeoPoint() => GeoPoint(
    latitude,
    longitude,
    // The plugin reports 0 when a value is not available.
    accuracy: accuracy > 0 ? accuracy : null,
    time: time > 0 ? DateTime.fromMillisecondsSinceEpoch(time.toInt()) : null,
  );
}
