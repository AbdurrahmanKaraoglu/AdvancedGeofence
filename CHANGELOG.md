## 0.1.0

### English
- First release.
- `CircleGeofence` and `PolygonGeofence`, each with id, name, metadata and an optional dwell time. Polygons and circles work across the antimeridian. Circles can also cover a pole.
- `GeofenceEngine` produces `enter`, `exit` and `dwell` events from any stream of `GeoPoint` readings. It has these noise filters:
  - exit hysteresis;
  - accuracy-weighted decisions;
  - N-reading confirmation;
  - out-of-order, duplicate, stale (or future-dated), invalid and low-accuracy readings are ignored.
- Saveable state (`engine.state.toJson()` / `GeofenceEngineState.fromJson()`), so a restarted background isolate continues without duplicate events.
- A grid spatial index (`GeofenceIndex`), so each reading only evaluates nearby geofences.
- An Android example app built on `advanced_background_locator` (English/Turkish, Material 3).

### Türkçe
- İlk sürüm.
- Kimlik, ad, meta veri ve isteğe bağlı bekleme süresi taşıyan `CircleGeofence` ve `PolygonGeofence`. Çokgenler ve daireler antimeridyeni geçebilir. Daireler bir kutbu da kapsayabilir.
- `GeofenceEngine`, herhangi bir `GeoPoint` akışından `enter`, `exit` ve `dwell` olayları üretir. Şu gürültü filtreleri vardır:
  - çıkış histerezisi;
  - doğruluğa göre ağırlıklı karar;
  - N okumayla teyit;
  - sırası bozuk, tekrar eden, eski (ya da ileri tarihli), geçersiz ve düşük doğruluklu okumalar yok sayılır.
- Kaydedilebilir durum (`engine.state.toJson()` / `GeofenceEngineState.fromJson()`). Yeniden başlayan arka plan isolate'i olayları tekrarlamadan kaldığı yerden devam eder.
- Izgara tabanlı uzamsal indeks (`GeofenceIndex`). Her okumada yalnızca yakındaki bölgeler hesaplanır.
- `advanced_background_locator` kullanan Android örnek uygulaması (Türkçe/İngilizce, Material 3).
