import 'geofence.dart';

/// A uniform latitude/longitude grid used to pre-filter geofences.
///
/// Each geofence is registered in every cell its bounding box touches, so a
/// lookup only has to look at the geofences of a single cell. Geofences that
/// would cover more than [maxCellsPerGeofence] cells are kept in a small list
/// that is always returned.
class GeofenceIndex {
  /// Creates an empty index with square cells of [cellDegrees] degrees.
  GeofenceIndex({this.cellDegrees = 0.05, this.maxCellsPerGeofence = 4096}) {
    if (!(cellDegrees >= 0.001) || cellDegrees > 360) {
      throw ArgumentError.value(cellDegrees, 'cellDegrees', 'must be between 0.001 and 360');
    }
    _rows = (180 / cellDegrees).ceil();
    _cols = (360 / cellDegrees).ceil();
  }

  /// Cell size in degrees.
  final double cellDegrees;

  /// Geofences covering more cells than this are always returned instead.
  final int maxCellsPerGeofence;

  late final int _rows;
  late final int _cols;
  final Map<int, List<Geofence>> _cells = {};
  final Map<String, List<int>> _keysById = {};
  final Map<String, Geofence> _large = {};

  int _row(double lat) => ((lat + 90) / cellDegrees).floor().clamp(0, _rows - 1);

  int _col(double lng) => ((lng + 180) / cellDegrees).floor().clamp(0, _cols - 1);

  /// Adds [geofence], replacing any geofence with the same id.
  void add(Geofence geofence) {
    remove(geofence.id);
    final b = geofence.bounds;
    final rowFrom = _row(b.south), rowTo = _row(b.north);
    final colRanges = b.crossesAntimeridian
        ? [(_col(b.west), _cols - 1), (0, _col(b.east))]
        : [(_col(b.west), _col(b.east))];
    var cells = 0;
    for (final (from, to) in colRanges) {
      cells += (rowTo - rowFrom + 1) * (to - from + 1);
    }
    if (cells > maxCellsPerGeofence) {
      _large[geofence.id] = geofence;
      return;
    }
    final keys = <int>[];
    for (var row = rowFrom; row <= rowTo; row++) {
      for (final (from, to) in colRanges) {
        for (var col = from; col <= to; col++) {
          final key = row * _cols + col;
          (_cells[key] ??= []).add(geofence);
          keys.add(key);
        }
      }
    }
    _keysById[geofence.id] = keys;
  }

  /// Removes the geofence with [id], if present.
  void remove(String id) {
    if (_large.remove(id) != null) return;
    final keys = _keysById.remove(id);
    if (keys == null) return;
    for (final key in keys) {
      final list = _cells[key]!;
      list.removeWhere((g) => g.id == id);
      if (list.isEmpty) _cells.remove(key);
    }
  }

  /// Geofences whose bounding box may contain the point. [lng] must be
  /// normalized to -180..180. Each geofence is returned at most once.
  Iterable<Geofence> candidates(double lat, double lng) sync* {
    final cell = _cells[_row(lat) * _cols + _col(lng)];
    if (cell != null) yield* cell;
    yield* _large.values;
  }
}
