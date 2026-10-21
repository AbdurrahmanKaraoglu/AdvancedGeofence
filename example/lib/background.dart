import 'dart:isolate';
import 'dart:ui';

import 'package:advanced_background_locator/advanced_background_locator.dart';
import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:flutter/foundation.dart';

import 'geofence_store.dart';
import 'location_adapter.dart';

/// Name of the UI isolate's port that receives updates from the background.
const String uiPortName = 'advanced_geofence_example';

/// The options used by the example (the package defaults, spelled out).
const GeofenceOptions exampleOptions = GeofenceOptions(
  hysteresis: 20,
  confirmations: 2,
  maxAccuracy: 100,
  maxReadingAge: Duration(minutes: 2),
);

// Everything below runs in the background isolate started by
// advanced_background_locator. Callbacks must be top-level (or static)
// functions annotated with @pragma('vm:entry-point') so that they survive
// tree shaking and can be looked up by the native side.

GeofenceEngine? _engine;
DateTime? _zonesModified;
final GeofenceStore _store = GeofenceStore();

/// Creates the engine on first use (restoring the saved state) and picks up
/// zone changes made by the UI.
Future<GeofenceEngine> _loadEngine() async {
  final modified = await _store.zonesModified();
  var engine = _engine;
  if (engine == null) {
    engine = GeofenceEngine(
      geofences: await _store.loadZones(),
      options: exampleOptions,
      state: await _store.loadState(),
    );
    _engine = engine;
  } else if (modified != _zonesModified) {
    final zones = await _store.loadZones();
    final ids = {for (final z in zones) z.id};
    for (final old in engine.geofences.toList()) {
      if (!ids.contains(old.id)) engine.removeGeofence(old.id);
    }
    engine.addGeofences(zones);
  }
  _zonesModified = modified;
  return engine;
}

@pragma('vm:entry-point')
Future<void> geofenceInitCallback(Map<dynamic, dynamic> params) async {
  debugPrint('advanced_geofence example: background isolate started');
  // Drop a cached engine from a previous run of this isolate; the saved
  // state is loaded again on the first location.
  _engine = null;
}

@pragma('vm:entry-point')
Future<void> geofenceLocationCallback(LocationDto location) async {
  final engine = await _loadEngine();
  final point = location.toGeoPoint();
  final result = engine.process(point);

  if (result.accepted) await _store.saveState(engine.state);
  if (result.events.isNotEmpty) await _store.appendEvents(result.events);

  final SendPort? ui = IsolateNameServer.lookupPortByName(uiPortName);
  ui?.send({
    'location': point.toJson(),
    if (result.ignoredReason != null) 'ignored': result.ignoredReason!.name,
    'events': [for (final e in result.events) e.toJson()],
  });
}

@pragma('vm:entry-point')
Future<void> geofenceDisposeCallback() async {
  debugPrint('advanced_geofence example: background isolate stopped');
  _engine = null;
}

@pragma('vm:entry-point')
Future<void> notificationTapCallback() async {}
