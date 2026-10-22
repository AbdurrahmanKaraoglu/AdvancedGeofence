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

To try it without walking around, play a simulated route on the emulator with [route_simulator](https://pub.dev/packages/route_simulator) (`dart run route_simulator:emulator --demo --realistic --device emulator-5554`) and add a zone along the way.

Dışarı çıkmadan denemek için emülatörde [route_simulator](https://pub.dev/packages/route_simulator) ile simüle edilmiş bir rota oynatın ve yol üzerine bir bölge ekleyin.
