import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:advanced_background_locator/advanced_background_locator.dart';
import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background.dart';
import 'geofence_store.dart';
import 'l10n/app_localizations.dart';

void main() => runApp(const GeofenceExampleApp());

const Color _brandColor = Color(0xFF0B3D91);
const Color _insideColor = Color(0xFF1B873F);

class GeofenceExampleApp extends StatelessWidget {
  const GeofenceExampleApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _brandColor, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Device languages other than Turkish fall back to English.
      localeResolutionCallback: (locale, supported) =>
          supported.firstWhere((l) => l.languageCode == locale?.languageCode, orElse: () => const Locale('en')),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const GeofencePage(),
    );
  }
}

class GeofencePage extends StatefulWidget {
  const GeofencePage({super.key});

  @override
  State<GeofencePage> createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final ReceivePort _port = ReceivePort();
  final GeofenceStore _store = GeofenceStore();

  bool _isRunning = false;
  bool _isBusy = false;
  GeoPoint? _lastPoint;
  IgnoreReason? _lastIgnored;
  List<Geofence> _zones = [];
  GeofenceEngineState? _state;
  List<GeofenceEvent> _events = [];

  @override
  void initState() {
    super.initState();
    // Replace a mapping left over from a previous UI isolate.
    IsolateNameServer.removePortNameMapping(uiPortName);
    IsolateNameServer.registerPortWithName(_port.sendPort, uiPortName);
    _port.listen(_onBackgroundMessage);
    _init();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(uiPortName);
    _port.close();
    super.dispose();
  }

  Future<void> _init() async {
    await AdvancedBackgroundLocator.initialize();
    final isRunning = await AdvancedBackgroundLocator.isServiceRunning();
    final zones = await _store.loadZones();
    final state = await _store.loadState();
    final events = await _store.loadEvents();
    if (!mounted) return;
    setState(() {
      _isRunning = isRunning;
      _zones = zones;
      _state = state;
      _events = events;
      _lastPoint = state?.lastPoint;
    });
  }

  /// Messages sent by [geofenceLocationCallback] from the background isolate.
  Future<void> _onBackgroundMessage(dynamic data) async {
    if (data is! Map) return;
    final location = data['location'] as Map?;
    final ignored = data['ignored'] as String?;
    final events = [
      for (final e in (data['events'] as List?) ?? const []) GeofenceEvent.fromJson((e as Map).cast<String, Object?>()),
    ];
    final state = await _store.loadState();
    if (!mounted) return;
    setState(() {
      if (location != null) _lastPoint = GeoPoint.fromJson(location.cast<String, Object?>());
      _lastIgnored = ignored == null ? null : IgnoreReason.values.byName(ignored);
      _state = state;
      _events = [...events.reversed, ..._events].take(GeofenceStore.maxEvents).toList();
    });
    if (events.isNotEmpty) await _updateNotification(events.last);
  }

  Future<void> _updateNotification(GeofenceEvent event) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await AdvancedBackgroundLocator.updateNotificationText(
      title: _eventTitle(l10n, event),
      msg: _formatTime(context, event.time.toLocal()),
    );
  }

  Future<void> _onStart() async {
    setState(() => _isBusy = true);
    try {
      final granted = await _requestPermissions();
      if (!mounted) return;
      if (!granted) {
        _showMessage(AppLocalizations.of(context).permissionDenied);
        return;
      }
      await _startLocator();
      final isRunning = await AdvancedBackgroundLocator.isServiceRunning();
      if (!mounted) return;
      setState(() => _isRunning = isRunning);
    } on PlatformException catch (e) {
      _showMessage(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _onStop() async {
    setState(() => _isBusy = true);
    await AdvancedBackgroundLocator.unRegisterLocationUpdate();
    final isRunning = await AdvancedBackgroundLocator.isServiceRunning();
    if (!mounted) return;
    setState(() {
      _isRunning = isRunning;
      _isBusy = false;
    });
  }

  /// Foreground location is required; background location ("Allow all the
  /// time") and notifications are requested but optional.
  Future<bool> _requestPermissions() async {
    if (!(await Permission.locationWhenInUse.request()).isGranted) return false;
    await Permission.notification.request();
    await Permission.locationAlways.request();
    return true;
  }

  Future<void> _startLocator() async {
    final l10n = AppLocalizations.of(context);
    await AdvancedBackgroundLocator.registerLocationUpdate(
      geofenceLocationCallback,
      initCallback: geofenceInitCallback,
      disposeCallback: geofenceDisposeCallback,
      iosSettings: const IOSSettings(accuracy: LocationAccuracy.NAVIGATION, distanceFilter: 5),
      androidSettings: AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: 5,
        distanceFilter: 5,
        client: LocationClient.google,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: l10n.notificationChannelName,
          notificationTitle: l10n.notificationTitle,
          notificationMsg: l10n.notificationMessage,
          notificationBigMsg: l10n.notificationBigMessage,
          notificationIconColor: _brandColor,
          notificationTapCallback: notificationTapCallback,
        ),
      ),
    );
  }

  Future<void> _addZone() async {
    final point = _lastPoint;
    if (point == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<(String, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddZoneSheet(defaultName: l10n.zoneNameDefault(_zones.length + 1)),
    );
    if (result == null) return;
    final zone = CircleGeofence(
      id: 'zone-${DateTime.now().millisecondsSinceEpoch}',
      name: result.$1,
      center: GeoPoint(point.latitude, point.longitude),
      radius: result.$2,
      dwellTime: const Duration(minutes: 1),
    );
    final zones = [..._zones, zone];
    // The background isolate notices the changed file on its next reading.
    await _store.saveZones(zones);
    if (!mounted) return;
    setState(() => _zones = zones);
  }

  Future<void> _deleteZone(Geofence zone) async {
    final zones = [
      for (final z in _zones)
        if (z.id != zone.id) z,
    ];
    await _store.saveZones(zones);
    if (!mounted) return;
    setState(() => _zones = zones);
  }

  Future<void> _clearEvents() async {
    await _store.clearEvents();
    if (!mounted) return;
    setState(() => _events = []);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              l10n.appSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.clearEvents,
            onPressed: _events.isEmpty ? null : _clearEvents,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StatusCard(isRunning: _isRunning),
            const SizedBox(height: 16),
            _ActionButton(isRunning: _isRunning, isBusy: _isBusy, onStart: _onStart, onStop: _onStop),
            const SizedBox(height: 28),
            _SectionHeader(title: l10n.sectionPosition),
            const SizedBox(height: 8),
            _PositionCard(
              point: _lastPoint,
              ignored: _lastIgnored,
              isRunning: _isRunning,
              onAddZone: _isRunning && _lastPoint != null ? _addZone : null,
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: l10n.sectionZones, trailing: _zones.isEmpty ? null : l10n.zoneCount(_zones.length)),
            const SizedBox(height: 8),
            _ZonesCard(zones: _zones, state: _state, point: _lastPoint, onDelete: _deleteZone),
            const SizedBox(height: 28),
            _SectionHeader(
              title: l10n.sectionEvents,
              trailing: _events.isEmpty ? null : l10n.eventCount(_events.length),
            ),
            const SizedBox(height: 8),
            _EventsCard(events: _events),
            const SizedBox(height: 20),
            Text(
              l10n.settingsSummary,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(BuildContext context, DateTime t) =>
    DateFormat.Hms(Localizations.localeOf(context).toLanguageTag()).format(t);

String _formatNumber(BuildContext context, double value, int decimals) => NumberFormat.decimalPatternDigits(
  locale: Localizations.localeOf(context).toLanguageTag(),
  decimalDigits: decimals,
).format(value);

String _meters(BuildContext context, double value) =>
    AppLocalizations.of(context).unitMeters(_formatNumber(context, value, 0));

String _eventTitle(AppLocalizations l10n, GeofenceEvent event) {
  final name = event.geofence.name ?? event.geofenceId;
  return switch (event.type) {
    GeofenceEventType.enter => l10n.eventEnter(name),
    GeofenceEventType.exit => l10n.eventExit(name),
    GeofenceEventType.dwell => l10n.eventDwell(name),
  };
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final Color accent = isRunning ? _insideColor : scheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isRunning ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isRunning ? Icons.radar : Icons.location_disabled_outlined,
                color: isRunning ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning ? l10n.statusActive : l10n.statusInactive,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRunning ? l10n.statusActiveDescription : l10n.statusInactiveDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Badge(label: isRunning ? l10n.badgeLive : l10n.badgeIdle, color: accent),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.isRunning, required this.isBusy, required this.onStart, required this.onStop});

  final bool isRunning;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final Widget icon = isBusy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: isRunning ? scheme.onError : scheme.onPrimary),
          )
        : Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded);

    return FilledButton.icon(
      onPressed: isBusy ? null : (isRunning ? onStop : onStart),
      style: isRunning ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
      icon: icon,
      label: Text(isRunning ? l10n.stopMonitoring : l10n.startMonitoring),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.point, required this.ignored, required this.isRunning, required this.onAddZone});

  final GeoPoint? point;
  final IgnoreReason? ignored;
  final bool isRunning;
  final VoidCallback? onAddZone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final p = point;
    if (p == null) {
      return _EmptyCard(
        icon: Icons.satellite_alt_outlined,
        message: isRunning ? l10n.waitingForLocation : l10n.noLocationYet,
      );
    }

    // Coordinates keep the decimal point in every language so they can be copied as-is.
    final metrics = <(String, String)>[
      (l10n.metricLatitude, p.latitude.toStringAsFixed(5)),
      (l10n.metricLongitude, p.longitude.toStringAsFixed(5)),
      (l10n.metricAccuracy, p.accuracy == null ? '-' : '± ${_meters(context, p.accuracy!)}'),
      (l10n.metricTime, p.time == null ? '-' : _formatTime(context, p.time!.toLocal())),
    ];
    final reason = switch (ignored) {
      IgnoreReason.lowAccuracy => l10n.ignoredLowAccuracy,
      IgnoreReason.stale => l10n.ignoredStale,
      IgnoreReason.outOfOrder => l10n.ignoredOutOfOrder,
      IgnoreReason.invalid => l10n.ignoredInvalid,
      null => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < metrics.length; row += 2) ...[
              if (row > 0) const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Metric(label: metrics[row].$1, value: metrics[row].$2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Metric(label: metrics[row + 1].$1, value: metrics[row + 1].$2),
                  ),
                ],
              ),
            ],
            if (reason != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.readingIgnored(reason),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAddZone,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.addZoneHere),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ZonesCard extends StatelessWidget {
  const _ZonesCard({required this.zones, required this.state, required this.point, required this.onDelete});

  final List<Geofence> zones;
  final GeofenceEngineState? state;
  final GeoPoint? point;
  final ValueChanged<Geofence> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (zones.isEmpty) return _EmptyCard(icon: Icons.layers_outlined, message: l10n.noZones);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < zones.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: scheme.outlineVariant),
            Builder(
              builder: (context) {
                final zone = zones[i];
                final status = state?.regions[zone.id]?.status ?? GeofenceStatus.unknown;
                final (label, color, icon) = switch (status) {
                  GeofenceStatus.inside => (l10n.statusInside, _insideColor, Icons.where_to_vote),
                  GeofenceStatus.outside => (l10n.statusOutside, scheme.outline, Icons.location_on_outlined),
                  GeofenceStatus.unknown => (l10n.statusUnknown, scheme.tertiary, Icons.help_outline),
                };
                final radius = zone is CircleGeofence ? _meters(context, zone.radius) : '-';
                final distance = point == null ? null : zone.signedDistance(point!).abs();
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(
                    zone.name ?? zone.id,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      l10n.zoneDetails(radius),
                      if (distance != null) l10n.zoneDistance(_meters(context, distance)),
                    ].join('\n'),
                  ),
                  isThreeLine: distance != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Badge(label: label, color: color),
                      IconButton(
                        tooltip: l10n.deleteZone,
                        onPressed: () => onDelete(zone),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  static const int _maxVisible = 50;

  final List<GeofenceEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (events.isEmpty) return _EmptyCard(icon: Icons.receipt_long_outlined, message: l10n.noEvents);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = events.take(_maxVisible).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: scheme.outlineVariant),
            ListTile(
              dense: true,
              leading: Icon(
                switch (visible[i].type) {
                  GeofenceEventType.enter => Icons.login,
                  GeofenceEventType.exit => Icons.logout,
                  GeofenceEventType.dwell => Icons.hourglass_bottom,
                },
                color: switch (visible[i].type) {
                  GeofenceEventType.enter => _insideColor,
                  GeofenceEventType.exit => scheme.error,
                  GeofenceEventType.dwell => scheme.primary,
                },
              ),
              title: Text(
                _eventTitle(l10n, visible[i]),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  _formatTime(context, visible[i].time.toLocal()),
                  if (visible[i].initial) l10n.eventInitial,
                ].join('  ·  '),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddZoneSheet extends StatefulWidget {
  const _AddZoneSheet({required this.defaultName});

  final String defaultName;

  @override
  State<_AddZoneSheet> createState() => _AddZoneSheetState();
}

class _AddZoneSheetState extends State<_AddZoneSheet> {
  static const List<double> _radii = [50, 100, 250, 500];

  late final TextEditingController _name = TextEditingController(text: widget.defaultName);
  double _radius = 100;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    Navigator.of(context).pop((name.isEmpty ? widget.defaultName : name, _radius));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.addZoneTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.zoneName, border: const OutlineInputBorder()),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(l10n.zoneRadius, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: [for (final r in _radii) ButtonSegment(value: r, label: Text(_meters(context, r)))],
            selected: {_radius},
            onSelectionChanged: (s) => setState(() => _radius = s.first),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _submit, child: Text(l10n.add)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
