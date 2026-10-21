# advanced_geofence example

An Android app (English/Turkish, Material 3) that runs `advanced_geofence` inside the background location callback of [`advanced_background_locator`](https://pub.dev/packages/advanced_background_locator).

- `lib/location_adapter.dart`: `LocationDto` → `GeoPoint` adapter.
- `lib/background.dart`: top-level `@pragma('vm:entry-point')` callbacks. They run the engine, save its state after each reading and send the events to the UI.
- `lib/geofence_store.dart`: file storage shared by the two isolates (zones, engine state, events).
- `lib/main.dart`: UI. Start monitoring, add a circular zone at your position, watch enter/exit/dwell events.

```bash
flutter run
```

Bölgeler, motor durumu ve olaylar dosyalara yazılır. Böylece arka plan isolate'i yeniden başladığında olaylar tekrarlanmadan kaldığı yerden devam edilir.
