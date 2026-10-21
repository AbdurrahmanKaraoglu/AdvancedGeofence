// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Bölge izleme';

  @override
  String get appSubtitle => 'advanced_geofence · arka plan konumu';

  @override
  String get statusActive => 'İzleme etkin';

  @override
  String get statusInactive => 'İzleme kapalı';

  @override
  String get statusActiveDescription => 'Uygulama arka plandayken de bölge olayları algılanır.';

  @override
  String get statusInactiveDescription => 'Bölgelerinize giriş ve çıkışları algılamak için izlemeyi başlatın.';

  @override
  String get badgeLive => 'Canlı';

  @override
  String get badgeIdle => 'Beklemede';

  @override
  String get startMonitoring => 'İzlemeyi başlat';

  @override
  String get stopMonitoring => 'İzlemeyi durdur';

  @override
  String get sectionPosition => 'Mevcut konum';

  @override
  String get waitingForLocation => 'İlk konum bekleniyor…';

  @override
  String get noLocationYet => 'Konumunuzu görmek için izlemeyi başlatın.';

  @override
  String get metricLatitude => 'Enlem';

  @override
  String get metricLongitude => 'Boylam';

  @override
  String get metricAccuracy => 'Doğruluk';

  @override
  String get metricTime => 'Saat';

  @override
  String readingIgnored(String reason) {
    return 'Son okuma yok sayıldı: $reason';
  }

  @override
  String get ignoredLowAccuracy => 'doğruluk düşük';

  @override
  String get ignoredStale => 'çok eski';

  @override
  String get ignoredOutOfOrder => 'sırası bozuk';

  @override
  String get ignoredInvalid => 'geçersiz koordinat';

  @override
  String get addZoneHere => 'Buraya bölge ekle';

  @override
  String get sectionZones => 'Bölgeler';

  @override
  String zoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count bölge', one: '1 bölge');
    return '$_temp0';
  }

  @override
  String get noZones => 'Henüz bölge yok. İzlemeyi başlatın, ardından konumunuza bir bölge ekleyin.';

  @override
  String zoneDetails(String radius) {
    return 'Yarıçap $radius · 1 dk sonra bekleme';
  }

  @override
  String zoneDistance(String distance) {
    return 'Sınıra $distance';
  }

  @override
  String get statusInside => 'İçeride';

  @override
  String get statusOutside => 'Dışarıda';

  @override
  String get statusUnknown => 'Belirsiz';

  @override
  String get deleteZone => 'Bölgeyi sil';

  @override
  String get sectionEvents => 'Olaylar';

  @override
  String eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count olay', one: '1 olay');
    return '$_temp0';
  }

  @override
  String get noEvents => 'Henüz olay yok.';

  @override
  String eventEnter(String name) {
    return '$name bölgesine girildi';
  }

  @override
  String eventExit(String name) {
    return '$name bölgesinden çıkıldı';
  }

  @override
  String eventDwell(String name) {
    return '$name bölgesinde bekleniyor';
  }

  @override
  String get eventInitial => 'başlangıçta zaten içerideydi';

  @override
  String get clearEvents => 'Olayları temizle';

  @override
  String get addZoneTitle => 'Yeni bölge';

  @override
  String get zoneName => 'Ad';

  @override
  String zoneNameDefault(int number) {
    return 'Bölge $number';
  }

  @override
  String get zoneRadius => 'Yarıçap';

  @override
  String get cancel => 'İptal';

  @override
  String get add => 'Ekle';

  @override
  String unitMeters(String value) {
    return '$value m';
  }

  @override
  String get settingsSummary => 'Histerezis 20 m  ·  2 teyit  ·  en fazla 100 m doğruluk';

  @override
  String get permissionDenied => 'Konum izni verilmedi.';

  @override
  String get notificationChannelName => 'Bölge izleme';

  @override
  String get notificationTitle => 'Bölge izleme etkin';

  @override
  String get notificationMessage => 'Bölgeleriniz arka planda izleniyor';

  @override
  String get notificationBigMessage => 'Bölgelerinize girip çıktığınızı algılamak için konum arka planda kullanılıyor.';
}
