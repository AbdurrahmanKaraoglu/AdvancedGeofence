# advanced_geofence

A pure Dart geofencing engine. Feed it location readings from **any** source and it emits `enter`, `exit` and `dwell` events for circle and polygon geofences, with noise filters and a state you can save and restore.

It pairs naturally with [`advanced_background_locator`](https://pub.dev/packages/advanced_background_locator) (run it inside the background location callback), but has no dependency on it, on Flutter or on any plugin.

[Türkçe açıklama aşağıda.](#türkçe)

## Features

- **Circle** (center + radius in meters) and **polygon** geofences, each with an `id`, optional `name`, `metadata` and dwell time.
- **Events:** `enter`, `exit` and `dwell` (stayed inside for a given time).
- **Noise filters:**
  - exit hysteresis buffer;
  - accuracy-aware decisions;
  - N consecutive readings to confirm a transition;
  - out-of-order, duplicate, stale (or future-dated), invalid and low-accuracy readings are ignored.
- **Resumable state:** `engine.state.toJson()` / `GeofenceEngineState.fromJson()`. When a background isolate restarts, the engine continues where it stopped, without duplicate events. You decide where to store it (file, database, preferences).
- **Scales to thousands of geofences:** a lat/lng grid pre-filters candidates, so each reading only evaluates nearby geofences and the ones you are in.
- Antimeridian-safe; circles may cover a pole.
- Synchronous, allocation-light, no timers. Works in any isolate, on the server and in tests.

## Why a pure Dart engine?

Most geofence packages on pub.dev wrap the OS geofencing APIs (Android `GeofencingClient`, iOS region monitoring). Those APIs save battery, but come with hard limits:

| | Android | iOS | advanced_geofence |
|---|---|---|---|
| Geofences per app | 100 | 20 | unlimited (grid index) |
| Shapes | circle | circle | circle + polygon |
| Dwell | yes | no (emulated) | yes |
| Reliable radius | ≥ 100–150 m recommended | similar | depends on your GPS readings |
| Behavior control | OS decides (latency, filtering) | OS decides | hysteresis, confirmations, accuracy, testable |
| Works without the app receiving locations | **yes** | **yes** | **no** |

Several pub.dev packages that run their own location polling (`geofence_service`, `poly_geofence_service`) are discontinued. Their successor, `geofencing_api`, is tied to one location plugin. This package separates the two concerns:

- **Location:** you choose the source (a foreground service, a simulator, recorded tracks, a server).
- **Geofencing:** a small deterministic engine that is fully unit tested.

Because the engine is pure Dart, you can run it inside a background location callback, replay recorded routes through it in tests, or run the same rules on your backend.

**The trade-off:** the OS does not watch the geofences for you. **If your app is not receiving location updates (e.g. it is killed and no background location service is running), no events can be produced.** If you need the OS to wake a killed app on a region crossing, use an OS geofence plugin instead, or combine both.

## Installation

```yaml
dependencies:
  advanced_geofence: ^0.1.2
```

## Usage

```dart
import 'package:advanced_geofence/advanced_geofence.dart';

final engine = GeofenceEngine(
  geofences: [
    CircleGeofence(
      id: 'office',
      name: 'Office',
      center: const GeoPoint(41.0082, 28.9784),
      radius: 150,
      dwellTime: const Duration(minutes: 5),
    ),
    PolygonGeofence(id: 'campus', vertices: const [
      GeoPoint(41.010, 28.970),
      GeoPoint(41.010, 28.985),
      GeoPoint(41.002, 28.985),
      GeoPoint(41.002, 28.970),
    ]),
  ],
);

// For every location reading:
final result = engine.process(GeoPoint(lat, lng, accuracy: accuracy, time: time));
for (final event in result.events) {
  print('${event.type.name} ${event.geofence.name ?? event.geofenceId} at ${event.time}');
}
if (!result.accepted) print('ignored: ${result.ignoredReason}');

// Or with a stream:
engine.monitor(readings).listen((event) { /* ... */ });
```

### Saving and restoring state

```dart
// After each reading:
await stateFile.writeAsString(jsonEncode(engine.state.toJson()));

// When the (background) isolate starts again:
GeofenceEngineState? saved;
try {
  saved = GeofenceEngineState.fromJson(jsonDecode(await stateFile.readAsString()));
} on FormatException {
  saved = null; // damaged or unknown data: start fresh
}
final engine = GeofenceEngine(geofences: geofences, state: saved);
```

States are matched to geofences by `id`. The state also stores the last reading, so readings that arrive late after a restart are still ignored. If that saved reading lies more than `maxReadingAge` in the future of the clock (the device clock was set back), it is not trusted and new readings are accepted.

If the saved data is damaged, or was written by an unknown format version, `fromJson` throws a `FormatException`. Catch it and start with a fresh engine. Later versions of this package keep reading states written by earlier ones.

### With advanced_background_locator

Background callbacks run in their own isolate and must be top-level (or static) functions annotated with `@pragma('vm:entry-point')`. The [example](example/) app shows the complete flow:

- convert each `LocationDto` to a `GeoPoint`;
- run the engine in the callback;
- save the state and the events to files;
- send the events to the UI through a `SendPort`.

```dart
extension LocationDtoToGeoPoint on LocationDto {
  GeoPoint toGeoPoint() => GeoPoint(
        latitude,
        longitude,
        accuracy: accuracy > 0 ? accuracy : null,
        time: time > 0 ? DateTime.fromMillisecondsSinceEpoch(time.toInt()) : null,
      );
}

GeofenceEngine? _engine;

@pragma('vm:entry-point')
Future<void> onLocation(LocationDto dto) async {
  final engine = _engine ??= await loadEngineFromFiles(); // your storage
  final result = engine.process(dto.toGeoPoint());
  await saveState(engine.state.toJson());
  for (final event in result.events) {
    IsolateNameServer.lookupPortByName('geofence_events')?.send(event.toJson());
  }
}
```

> `cloud_firestore` and `route_simulator` also have a `GeoPoint` class. If you use one of them, import it (or this package) with a prefix, e.g. `import 'package:route_simulator/route_simulator.dart' as sim;`.

## Used together

advanced_geofence only needs `GeoPoint`s, so it works with any source. These packages from the same author fit around it:

| Package | What it adds |
|---|---|
| [advanced_background_locator](https://pub.dev/packages/advanced_background_locator) | The location source: background locations on Android (foreground service) and iOS. Run the engine in its callback, as the [example](example/) does. |
| [route_simulator](https://pub.dev/packages/route_simulator) | Test your geofences at your desk: realistic, noisy, repeatable GPS along a route, in unit tests or on the Android emulator. |
| [google_maps_polyline](https://pub.dev/packages/google_maps_polyline) | Fetch a real route (Google Directions) or decode a polyline, e.g. to simulate it with route_simulator. |
| [marker_crafter](https://pub.dev/packages/marker_crafter) | Draw zone labels and pins on Google Maps. |
| [animated_route_marker](https://pub.dev/packages/animated_route_marker) | Move the tracked position smoothly on the map. |
| [flutter_toastify](https://pub.dev/packages/flutter_toastify) | Show enter/exit/dwell events as in-app toasts. |
| [turkish_kit](https://pub.dev/packages/turkish_kit) | Sort zone names correctly in Turkish (ı/i) and name zones after provinces and districts. |

### Testing geofences with route_simulator

route_simulator produces deterministic fixes with noise, GPS jumps and signal losses. Feed them to the engine to check your geofences and options without walking around. It has its own `GeoPoint`, so import it with a prefix. Its fixes carry recorded timestamps, so turn off `maxReadingAge`:

```dart
import 'package:advanced_geofence/advanced_geofence.dart';
import 'package:route_simulator/route_simulator.dart' as sim;

final simulator = sim.RouteSimulator(
  route: sim.SimRoute.fromEncodedPolyline(encoded),
  profile: const sim.SpeedProfile.constant(1.4), // walking, m/s
  stops: const [sim.RouteStop.atPoint(3, Duration(minutes: 2))],
  noise: const sim.GpsNoise(horizontalError: 4, jumpProbability: 0.02, seed: 42),
  startTime: DateTime.utc(2026, 1, 1, 9),
);
final engine = GeofenceEngine(
  geofences: geofences,
  options: const GeofenceOptions(maxReadingAge: null),
);
final events = [
  for (final l in simulator.generate())
    ...engine.process(GeoPoint(l.latitude, l.longitude, accuracy: l.accuracy, time: l.time)).events,
];
```

To try the example app on the Android emulator, play a route with route_simulator's command line tool, which sends `geo fix` commands to the emulator (see its README for the options):

```bash
dart run route_simulator:emulator --demo --realistic --rate 5 --device emulator-5554
```

## How decisions are made

For each reading the engine computes the signed distance `d` to every relevant geofence boundary (negative inside). With `margin = accuracy × accuracyWeight`:

- **inside** if `d ≤ −margin`;
- **outside** if `d ≥ margin`, plus `hysteresis` when the device is currently inside;
- anything in between is **ambiguous**. It neither counts towards a pending transition nor resets it.

A transition needs `confirmations` consecutive readings. The event's `since` is the time of the first of them. Dwell fires once per stay, when `time − since ≥ dwellTime`. Dwell is checked on every reading, or with `engine.advanceTime()` from a timer. While an exit is being confirmed, dwell is held back, so a device that is already leaving does not get a late dwell. If the exit turns out to be a GPS spike, the dwell comes with the next reading inside.

| Option | Default | Meaning |
|---|---|---|
| `hysteresis` | 20 m | extra distance beyond the boundary before an exit |
| `confirmations` | 2 | consecutive readings to confirm a transition |
| `maxAccuracy` | 100 m | worse readings are ignored |
| `accuracyWeight` | 0.5 | share of the accuracy radius that must be on the far side |
| `maxReadingAge` | 5 min | readings further than this from the clock (old or future) are ignored; `null` for replays/simulations |
| `notifyInitialEnter` | true | emit `enter` (with `initial: true`) if already inside at start |
| `defaultDwellTime` | null | dwell time for geofences without their own |
| `gridCellDegrees` | 0.05 | spatial index cell size |

Tips:

- Use a radius of **at least 50–100 m**. Phone GPS accuracy is often 5–20 m outdoors and 30–100 m or worse indoors and between tall buildings.
- If a geofence is smaller than `accuracy × accuracyWeight`, the device can never be confidently inside it.

### Geometry notes

- **Distances:** haversine on a spherical Earth (radius 6 371 008.8 m).
- **Polygon containment:** ray casting with the even-odd rule. Edges are straight lines in lat/lng, and distance to an edge uses a local planar approximation. This is accurate for geofences up to a few tens of kilometers.
- **Antimeridian:** polygons and circles may cross ±180°.
- **Poles:** polygons must not enclose a pole (an `ArgumentError` is thrown). Use a circle, which handles the poles.
- **Valid polygons:** at least three vertices that are not all on one line. Consecutive vertices must be less than 180° of longitude apart. A repeated closing vertex is optional.

## Battery and permissions

This package does not request locations or permissions; your location source does.

- **Background location** needs "Allow all the time" on Android 10+ and iOS. On Android 12+ a foreground service must be started while the app is visible. Google Play and the App Store review background location use, so explain the feature to users.
- **Battery:** continuous GPS is the main battery cost, not the engine. Keep the accuracy and interval as low as your geofences allow (e.g. a distance filter of 10–20 m for 100 m geofences). Stop tracking when no geofences are active.
- **OEM battery savers** (Xiaomi, Huawei, Samsung…) may kill background services. If the service stops, no events are produced until locations flow again. Within the first readings after a restart (`confirmations` of them), the engine sees where you are and emits any missed `enter`/`exit`.

## Example

[`example/`](example/) is an Android app (English/Turkish, Material 3) built on `advanced_background_locator`:

- add circular geofences at your current position;
- start background tracking;
- see the enter/exit/dwell events, also with the app in the background.

## Other packages

More packages by the same author:

- [google_maps_polyline](https://pub.dev/packages/google_maps_polyline): Google Directions routes and polyline encode/decode (pure Dart)
- [marker_crafter](https://pub.dev/packages/marker_crafter): Custom Google Maps markers drawn with Canvas
- [animated_route_marker](https://pub.dev/packages/animated_route_marker): Smoothly animated map marker along a route or live GPS
- [advanced_background_locator](https://pub.dev/packages/advanced_background_locator): Background location tracking plugin (Android/iOS)
- [route_simulator](https://pub.dev/packages/route_simulator): Realistic fake GPS streams for testing and demos
- [background_doctor](https://pub.dev/packages/background_doctor): Diagnoses why background work stops on Android and why the app was killed
- [scan_tally](https://pub.dev/packages/scan_tally): Continuous barcode scanning for stock counts: dedupe, tally, feedback, GS1
- [scan_tally_mobile_scanner](https://pub.dev/packages/scan_tally_mobile_scanner): mobile_scanner camera adapter for scan_tally
- [turkish_kit](https://pub.dev/packages/turkish_kit): Turkish validators, money in words, casing, provinces, holidays (pure Dart)
- [turkish_kit_flutter](https://pub.dev/packages/turkish_kit_flutter): Flutter widgets for turkish_kit: Turkish money field and input formatters
- [flutter_toastify](https://pub.dev/packages/flutter_toastify): Animated toast notifications

## License

MIT — see [LICENSE](LICENSE).

---

## Türkçe

Saf Dart ile yazılmış bir coğrafi sınır (geofence) motoru. Konumu **herhangi bir** kaynaktan verirsiniz; motor daire ve çokgen bölgeler için `enter` (giriş), `exit` (çıkış) ve `dwell` (bekleme) olayları üretir. Gürültü filtreleri vardır ve durumu kaydedip geri yükleyebilirsiniz.

[`advanced_background_locator`](https://pub.dev/packages/advanced_background_locator) ile birlikte kullanılmak üzere tasarlandı: motoru arka plan konum callback'inin içinde çalıştırırsınız. Yine de ona, Flutter'a ya da herhangi bir eklentiye bağımlı değildir.

### Özellikler

- **Daire** (merkez + metre cinsinden yarıçap) ve **çokgen** bölgeler. Her bölgenin bir `id`'si vardır; isteğe bağlı olarak `name`, `metadata` ve bekleme süresi verilebilir.
- **Olaylar:** `enter`, `exit`, `dwell` (bölgede belirli bir süre kalındı).
- **Gürültü filtreleri:**
  - çıkış için histerezis tamponu;
  - konum doğruluğunu (`accuracy`) hesaba katan karar;
  - geçişi art arda N okumayla teyit;
  - sırası bozuk, tekrar eden, eski (ya da ileri tarihli), geçersiz ve düşük doğruluklu okumalar yok sayılır.
- **Kaldığı yerden devam:** `engine.state.toJson()` / `GeofenceEngineState.fromJson()`. Arka plan isolate'i yeniden başladığında motor kaldığı yerden devam eder ve olaylar tekrarlanmaz. Durumun nerede saklanacağına (dosya, veritabanı, preferences) siz karar verirsiniz.
- **Binlerce bölge:** bir enlem/boylam ızgarası adayları önceden eler. Her okumada yalnızca yakındaki bölgeler ve içinde bulunulan bölgeler hesaplanır.
- Antimeridyen (±180°) güvenli; daireler kutbu kapsayabilir.
- Senkron çalışır, zamanlayıcı kullanmaz. Her isolate'te, sunucuda ve testlerde çalışır.

### Neden saf Dart motor?

pub.dev'deki geofence paketlerinin çoğu işletim sisteminin geofence API'lerini sarar (Android `GeofencingClient`, iOS bölge izleme). Bu API'ler pil dostudur ama sert sınırları vardır:

- **Bölge sayısı:** Android'de en fazla 100, iOS'ta en fazla 20 bölge izlenebilir.
- **Şekil:** yalnızca daire.
- **Bekleme:** iOS'ta dwell yok.
- **Yarıçap:** en az 100–150 m önerilir.
- **Davranış:** gecikmeye ve filtrelemeye işletim sistemi karar verir.

Kendi konum sorgulamasını yapan paketlerin bir kısmının (`geofence_service`, `poly_geofence_service`) geliştirilmesi durduruldu. Yerlerine önerilen `geofencing_api` ise tek bir konum eklentisine bağlı.

Bu paket iki işi birbirinden ayırır:

- **Konum:** kaynağı siz seçersiniz (ön plan servisi, simülatör, kayıtlı rota, sunucu).
- **Geofence:** küçük, deterministik ve tamamen birim testli bir motor.

**Bedeli:** bölgeleri işletim sistemi izlemez. **Uygulamanız konum almıyorsa (örneğin uygulama kapatılmış ve arka planda konum servisi çalışmıyorsa) hiçbir olay üretilemez.** Kapalı uygulamanın bir bölge geçişinde işletim sistemi tarafından uyandırılması gerekiyorsa işletim sistemi geofence'i kullanan bir eklenti seçin ya da ikisini birlikte kullanın.

### Kullanım

```dart
final engine = GeofenceEngine(geofences: [
  CircleGeofence(id: 'ofis', name: 'Ofis', center: const GeoPoint(41.0082, 28.9784), radius: 150),
]);

final sonuc = engine.process(GeoPoint(enlem, boylam, accuracy: dogruluk, time: zaman));
for (final olay in sonuc.events) {
  print('${olay.type.name} ${olay.geofenceId}');
}

// Durumu kaydetme:
await dosya.writeAsString(jsonEncode(engine.state.toJson()));
// Geri yükleme:
GeofenceEngine(geofences: bolgeler, state: GeofenceEngineState.fromJson(jsonDecode(icerik)));
```

`advanced_background_locator` ile tam akış [example](example/) uygulamasında gösterilir. Arka plan callback'leri ayrı bir isolate'te çalışır ve top-level (ya da static) olmalı, ayrıca `@pragma('vm:entry-point')` ile işaretlenmelidir. Örnek uygulama:

- `LocationDto` → `GeoPoint` dönüşümünü yapar;
- motoru callback içinde çalıştırır;
- durumu ve olayları dosyaya yazar;
- olayları `SendPort` ile arayüze iletir.

Kayıtlı veri bozuksa ya da bilinmeyen bir biçim sürümüyle yazılmışsa `fromJson` bir `FormatException` fırlatır. Bunu yakalayıp yeni bir motorla başlayın. Paketin sonraki sürümleri önceki sürümlerin yazdığı durumu okumaya devam eder. Kayıtlı son okuma saatten `maxReadingAge` kadardan fazla ilerideyse (cihaz saati geri alınmışsa) ona güvenilmez ve yeni okumalar kabul edilir.

### Birlikte kullanım

advanced_geofence yalnızca `GeoPoint` bekler, bu yüzden her konum kaynağıyla çalışır. Aynı geliştiricinin şu paketleri onu tamamlar:

| Paket | Kattığı |
|---|---|
| [advanced_background_locator](https://pub.dev/packages/advanced_background_locator) | Konum kaynağı: Android'de (ön plan servisi) ve iOS'ta arka plan konumu. Motoru [example](example/) uygulamasındaki gibi onun callback'inde çalıştırın. |
| [route_simulator](https://pub.dev/packages/route_simulator) | Bölgeleri masa başında test edin: bir rota boyunca gerçekçi, gürültülü ve tekrarlanabilir GPS; birim testlerinde ya da Android emülatöründe. |
| [google_maps_polyline](https://pub.dev/packages/google_maps_polyline) | Gerçek bir rota alın (Google Directions) ya da polyline çözün; örneğin route_simulator ile oynatmak için. |
| [marker_crafter](https://pub.dev/packages/marker_crafter) | Bölge etiketlerini ve işaretçilerini Google Maps'te çizin. |
| [animated_route_marker](https://pub.dev/packages/animated_route_marker) | İzlenen konumu haritada akıcı biçimde hareket ettirin. |
| [flutter_toastify](https://pub.dev/packages/flutter_toastify) | Giriş/çıkış/bekleme olaylarını uygulama içi bildirim (toast) olarak gösterin. |
| [turkish_kit](https://pub.dev/packages/turkish_kit) | Bölge adlarını Türkçeye göre doğru sıralayın (ı/i), bölgeleri il ve ilçe adlarıyla adlandırın. |

route_simulator ile test: simülatörün `generate()` çıktısını yukarıdaki İngilizce örnekteki gibi motora verin. route_simulator'ın da bir `GeoPoint` sınıfı olduğu için onu önekle içe aktarın (`as sim`). Kayıtlı zaman damgaları kullandığı için `GeofenceOptions(maxReadingAge: null)` verin. Örnek uygulamayı Android emülatöründe denemek için bir rotayı route_simulator'ın komut satırı aracıyla oynatın; araç emülatöre `geo fix` komutları gönderir: `dart run route_simulator:emulator --demo --realistic --rate 5 --device emulator-5554`.

### Kararlar nasıl verilir?

Her okumada bölge sınırına işaretli uzaklık `d` hesaplanır (içeride negatif). `pay = accuracy × accuracyWeight` olmak üzere:

- `d ≤ −pay` ise **içeride**;
- `d ≥ pay` ise **dışarıda** (cihaz içerideyken buna `hysteresis` eklenir);
- arada kalan okuma **belirsizdir**. Bekleyen bir geçişe ne sayılır ne de onu sıfırlar.

Geçiş için art arda `confirmations` okuma gerekir. Olayın `since` alanı bu okumaların ilkinin zamanıdır. Dwell, her kalışta bir kez, `zaman − since ≥ dwellTime` olduğunda üretilir. Okuma seyrekse bir zamanlayıcıdan `engine.advanceTime()` çağırın. Bir çıkış teyit edilirken dwell bekletilir; böylece zaten çıkmakta olan cihaza geç bir dwell üretilmez. Çıkış bir GPS sıçraması çıkarsa dwell, içerideki bir sonraki okumayla gelir.

Varsayılanlar:

| Seçenek | Varsayılan |
|---|---|
| `hysteresis` | 20 m |
| `confirmations` | 2 |
| `maxAccuracy` | 100 m |
| `accuracyWeight` | 0,5 |
| `maxReadingAge` | 5 dk (saatten bu kadar uzak, eski ya da ileri tarihli okumalar yok sayılır; simülasyonlarda `null` verin) |
| `notifyInitialEnter` | `true` |
| `defaultDwellTime` | `null` |
| `gridCellDegrees` | 0,05 |

En az **50–100 m** yarıçap kullanın. Telefon GPS doğruluğu açık alanda çoğunlukla 5–20 m, kapalı alanda ve yüksek binalar arasında 30–100 m ya da daha kötüdür.

### Geometri notları

- **Uzaklık:** küresel Dünya üzerinde haversine formülü.
- **Çokgen içi testi:** ışın atma (çift-tek kuralı). Kenarlar enlem/boylam düzleminde düz çizgidir ve uzaklık yerel düzlem yaklaşımıyla hesaplanır. Birkaç on kilometreye kadar bölgelerde doğrudur.
- **Antimeridyen:** çokgenler ve daireler ±180°'yi geçebilir.
- **Kutuplar:** kutbu çevreleyen çokgen desteklenmez (`ArgumentError` fırlatılır). Bunun yerine daire kullanın.
- **Geçerli çokgen:** hepsi tek bir doğru üzerinde olmayan en az üç köşe. Ardışık köşeler arasındaki boylam farkı 180°'den az olmalıdır. Kapanış köşesini tekrar etmek isteğe bağlıdır.
- **`GeoPoint` çakışması:** `cloud_firestore` ve `route_simulator` da bir `GeoPoint` sınıfı içerir. Bunlardan birini kullanıyorsanız paketlerden birini önekle içe aktarın (örneğin `as sim`).

### Pil ve izinler

Bu paket konum ya da izin istemez; bunu konum kaynağınız yapar.

- **Arka plan konumu:** Android 10+ ve iOS'ta "Her zaman izin ver" gerekir. Android 12+'da ön plan servisi uygulama görünürken başlatılmalıdır. Google Play ve App Store arka plan konum kullanımını inceler, bu yüzden özelliği kullanıcıya açıklayın.
- **Pil:** pili harcayan motor değil, sürekli GPS'tir. Doğruluğu ve aralığı bölgelerinizin izin verdiği kadar düşük tutun (örneğin 100 m'lik bölgeler için 10–20 m mesafe filtresi). Etkin bölge yokken takibi durdurun.
- **Üretici pil tasarrufu:** Xiaomi, Huawei, Samsung gibi üreticilerin pil tasarrufu servisleri arka plan servisini öldürebilir. Servis durursa konum yeniden gelene kadar olay üretilmez. Yeniden başladıktan sonraki ilk okumalarda (`confirmations` kadar) motor nerede olduğunuzu görür ve kaçırılan `enter`/`exit` olayını üretir.

### Diğer paketler

Aynı geliştiricinin diğer paketleri:

- [google_maps_polyline](https://pub.dev/packages/google_maps_polyline): Google Directions rotası ve polyline kodlama/çözme (saf Dart)
- [marker_crafter](https://pub.dev/packages/marker_crafter): Canvas ile çizilen özel Google Maps işaretçileri
- [animated_route_marker](https://pub.dev/packages/animated_route_marker): Rota ya da canlı GPS üzerinde akıcı hareket eden harita işaretçisi
- [advanced_background_locator](https://pub.dev/packages/advanced_background_locator): Arka planda konum takibi eklentisi (Android/iOS)
- [route_simulator](https://pub.dev/packages/route_simulator): Test ve demo için gerçekçi sahte GPS akışı
- [background_doctor](https://pub.dev/packages/background_doctor): Android'de arka plan işinin neden durduğunu ve uygulamanın neden kapandığını teşhis eder
- [scan_tally](https://pub.dev/packages/scan_tally): Stok sayımı için sürekli barkod okutma: tekrar ayıklama, sayım, geri bildirim, GS1
- [scan_tally_mobile_scanner](https://pub.dev/packages/scan_tally_mobile_scanner): scan_tally için mobile_scanner kamera adaptörü
- [turkish_kit](https://pub.dev/packages/turkish_kit): Türkçe doğrulayıcılar, tutarı yazıyla yazma, harf dönüşümü, il/ilçe, tatiller (saf Dart)
- [turkish_kit_flutter](https://pub.dev/packages/turkish_kit_flutter): turkish_kit için Flutter bileşenleri: Türk biçimli para alanı ve girdi biçimleyicileri
- [flutter_toastify](https://pub.dev/packages/flutter_toastify): Animasyonlu toast bildirimleri

### Lisans

MIT — [LICENSE](LICENSE) dosyasına bakın.
