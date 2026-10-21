import 'dart:convert';
import 'dart:io';

import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:path_provider/path_provider.dart';

/// File storage shared by the UI isolate and the background isolate.
///
/// advanced_geofence leaves storage to the app. This example keeps three
/// files in the application support directory:
/// - `zones.json`: the geofences, written by the UI;
/// - `engine_state.json`: the engine state, written by the background isolate
///   after every reading so it can resume after a restart;
/// - `events.jsonl`: the produced events, one JSON object per line.
class GeofenceStore {
  static const int maxEvents = 200;

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name');
  }

  /// Writes through a temporary file, so the other isolate never reads a
  /// half-written file.
  Future<void> _writeAtomic(String name, String content) async {
    final file = await _file(name);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }

  Future<String?> _read(String name) async {
    final file = await _file(name);
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  Future<List<Geofence>> loadZones() async {
    final content = await _read('zones.json');
    if (content == null || content.isEmpty) return [];
    return [for (final json in jsonDecode(content) as List) Geofence.fromJson((json as Map).cast<String, Object?>())];
  }

  Future<void> saveZones(List<Geofence> zones) =>
      _writeAtomic('zones.json', jsonEncode([for (final z in zones) z.toJson()]));

  /// Last modification time of the zone file, used by the background isolate
  /// to notice that the UI changed the zones.
  Future<DateTime?> zonesModified() async {
    final file = await _file('zones.json');
    return await file.exists() ? file.lastModified() : null;
  }

  Future<GeofenceEngineState?> loadState() async {
    final content = await _read('engine_state.json');
    if (content == null || content.isEmpty) return null;
    try {
      return GeofenceEngineState.fromJson(jsonDecode(content) as Map<String, Object?>);
    } on FormatException {
      return null; // Corrupt or from an incompatible version: start fresh.
    }
  }

  Future<void> saveState(GeofenceEngineState state) => _writeAtomic('engine_state.json', jsonEncode(state.toJson()));

  /// Newest first.
  Future<List<GeofenceEvent>> loadEvents() async {
    final content = await _read('events.jsonl');
    if (content == null) return [];
    final events = <GeofenceEvent>[];
    for (final line in const LineSplitter().convert(content)) {
      if (line.trim().isEmpty) continue;
      try {
        events.add(GeofenceEvent.fromJson(jsonDecode(line) as Map<String, Object?>));
      } on FormatException {
        // Skip a damaged line.
      }
    }
    return events.reversed.toList();
  }

  Future<void> appendEvents(List<GeofenceEvent> events) async {
    final existing = (await _read('events.jsonl')) ?? '';
    final lines = [
      ...const LineSplitter().convert(existing).where((l) => l.trim().isNotEmpty),
      for (final e in events) jsonEncode(e.toJson()),
    ];
    final kept = lines.length > maxEvents ? lines.sublist(lines.length - maxEvents) : lines;
    await _writeAtomic('events.jsonl', '${kept.join('\n')}\n');
  }

  Future<void> clearEvents() => _writeAtomic('events.jsonl', '');
}
