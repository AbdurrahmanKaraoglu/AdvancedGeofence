/// Pure Dart geofencing engine: turns any stream of location readings into
/// enter, exit and dwell events for circle and polygon geofences.
library;

export 'src/geo_bounds.dart';
export 'src/geo_math.dart' show distanceBetween, earthRadiusMeters;
export 'src/geo_point.dart';
export 'src/geofence.dart';
export 'src/geofence_engine.dart';
export 'src/geofence_event.dart';
export 'src/geofence_index.dart';
export 'src/geofence_options.dart';
export 'src/geofence_state.dart';
