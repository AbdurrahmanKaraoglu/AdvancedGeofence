## 0.1.1

### English
- Fixed: a dwell event could fire while an exit was being confirmed, i.e. when the device had already left. Dwell now waits until the exit is confirmed (no dwell) or turns out to be a GPS spike (dwell on the next reading inside). `advanceTime` follows the same rule.
- Fixed: after restoring a state whose last reading lies more than `maxReadingAge` in the future (the device clock was set back), every new reading was ignored as out of order. Such a last reading is no longer trusted.
- Fixed: `fromJson` of `GeofenceEngineState`, `GeofenceRegionState`, `Geofence`, `GeofenceEvent` and `GeoPoint` now throws a `FormatException` for malformed input (wrong types, unknown status names, invalid values) instead of a `TypeError`/`ArgumentError`. One `on FormatException` catch is enough to start fresh.
- `PolygonGeofence` rejects polygons whose vertices are all on one line, which could never be entered.
- Tests: polygon edge cases (points on vertices and edges, repeated vertices, longitudes beyond 180°), a fixed version 1 state that later versions must keep reading, README examples, and noisy walks simulated with `route_simulator` (dev dependency only).
- README: new "Used together" section (advanced_background_locator, route_simulator, google_maps_polyline, marker_crafter, animated_route_marker, flutter_toastify, turkish_kit), testing with route_simulator, the `GeoPoint` name clash with route_simulator, and recovering from a damaged state file.

### Türkçe
- Düzeltildi: bir çıkış teyit edilirken, yani cihaz bölgeden zaten çıkmışken dwell olayı üretilebiliyordu. Dwell artık çıkış teyit edilene (dwell yok) ya da çıkışın bir GPS sıçraması olduğu anlaşılana kadar (içerideki bir sonraki okumada dwell) bekliyor. `advanceTime` de aynı kurala uyuyor.
- Düzeltildi: son okuması saatten `maxReadingAge` kadardan fazla ileride olan bir durum geri yüklendiğinde (cihaz saati geri alınmışsa) yeni okumaların hepsi "sırası bozuk" diye yok sayılıyordu. Böyle bir son okumaya artık güvenilmiyor.
- Düzeltildi: `GeofenceEngineState`, `GeofenceRegionState`, `Geofence`, `GeofenceEvent` ve `GeoPoint` sınıflarının `fromJson` metotları bozuk girdide (yanlış tür, bilinmeyen durum adı, geçersiz değer) `TypeError`/`ArgumentError` yerine `FormatException` fırlatıyor. Sıfırdan başlamak için tek bir `on FormatException` yeterli.
- `PolygonGeofence`, köşelerinin hepsi tek bir doğru üzerinde olan (içine hiç girilemeyecek) çokgenleri reddediyor.
- Testler: çokgen sınır durumları (köşe ve kenar üzerindeki noktalar, tekrar eden köşeler, 180°'yi aşan boylamlar), sonraki sürümlerin okumaya devam etmesi gereken sabit bir sürüm 1 durumu, README örnekleri ve `route_simulator` ile simüle edilmiş gürültülü yürüyüşler (yalnızca dev bağımlılığı).
- README: yeni "Birlikte kullanım" bölümü (advanced_background_locator, route_simulator, google_maps_polyline, marker_crafter, animated_route_marker, flutter_toastify, turkish_kit), route_simulator ile test, route_simulator ile `GeoPoint` isim çakışması ve bozuk durum dosyasından kurtulma.

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
