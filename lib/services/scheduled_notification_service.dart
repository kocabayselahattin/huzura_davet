import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'konum_service.dart';
import 'diyanet_api_service.dart';

/// Zamanlanmış bildirim servisi - Uygulama kapalıyken bile vakit bildirimlerini gönderir
class ScheduledNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Vakit isimleri
  static const List<String> _vakitler = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];
  
  // Vakit Türkçe isimleri
  static const Map<String, String> _vakitTurkce = {
    'Imsak': 'İmsak',
    'Gunes': 'Güneş',
    'Ogle': 'Öğle',
    'Ikindi': 'İkindi',
    'Aksam': 'Akşam',
    'Yatsi': 'Yatsı',
  };

  /// Servisi başlat
  static Future<void> initialize() async {
    if (_initialized) return;

    // Timezone verilerini yükle
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Bildirime tıklandı: ${response.payload}');
      },
    );

    _initialized = true;
    debugPrint('✅ Zamanlanmış bildirim servisi başlatıldı');
  }

  /// Tüm vakit bildirimlerini zamanla
  static Future<void> scheduleAllPrayerNotifications() async {
    try {
      // Önce mevcut bildirimleri iptal et
      await cancelAllNotifications();

      // Konum ID'sini al
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        debugPrint('⚠️ Konum seçilmemiş, bildirimler zamanlanamadı');
        return;
      }

      // Bugünün vakitlerini al
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler == null) {
        debugPrint('⚠️ Vakit bilgisi alınamadı');
        return;
      }

      // Kullanıcı ayarlarını yükle
      final prefs = await SharedPreferences.getInstance();

      // Her vakit için bildirim zamanla
      for (int i = 0; i < _vakitler.length; i++) {
        final vakitKey = _vakitler[i];
        final vakitKeyLower = vakitKey.toLowerCase();
        
        // Bildirim açık mı kontrol et
        final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;
        if (!bildirimAcik) {
          debugPrint('🔇 $vakitKey bildirimi kapalı, atlanıyor');
          continue;
        }

        final vakitSaati = vakitler[vakitKey];
        if (vakitSaati == null || vakitSaati == '—:—') continue;

        // Erken bildirim süresi (dakika)
        final erkenDakika = prefs.getInt('erken_$vakitKeyLower') ?? 0;
        
        // Vaktinde bildirim
        final vaktindeBildirim = prefs.getBool('vaktinde_$vakitKeyLower') ?? false;
        
        // Ses dosyası
        final sesDosyasi = prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'Ding_Dong.mp3';

        // Vakit saatini parse et
        final parts = vakitSaati.split(':');
        if (parts.length != 2) continue;
        
        final saat = int.tryParse(parts[0]);
        final dakika = int.tryParse(parts[1]);
        if (saat == null || dakika == null) continue;

        // Bildirim zamanını hesapla
        final now = DateTime.now();
        var bildirimZamani = DateTime(now.year, now.month, now.day, saat, dakika);
        
        // Erken bildirim süresi varsa çıkar
        if (erkenDakika > 0) {
          bildirimZamani = bildirimZamani.subtract(Duration(minutes: erkenDakika));
        }

        // Eğer zaman geçmişse, bildirimi atla
        if (bildirimZamani.isBefore(now)) {
          debugPrint('⏰ $vakitKey vakti geçmiş, atlanıyor');
          continue;
        }

        // Bildirimi zamanla
        await _scheduleNotification(
          id: i + 1, // 1-6 arası ID
          title: '${_vakitTurkce[vakitKey]} Vakti ${erkenDakika > 0 ? "Yaklaşıyor" : "Girdi"}',
          body: erkenDakika > 0 
              ? '${_vakitTurkce[vakitKey]} vaktine $erkenDakika dakika kaldı'
              : '${_vakitTurkce[vakitKey]} vakti girdi. Hayırlı ibadetler!',
          scheduledTime: bildirimZamani,
          soundAsset: sesDosyasi,
        );
        
        debugPrint('✅ $vakitKey bildirimi zamanlandı: ${bildirimZamani.hour}:${bildirimZamani.minute.toString().padLeft(2, '0')}');

        // Vaktinde bildirim de isteniyorsa ve erken bildirim varsa, ayrıca vaktinde de bildirim gönder
        if (vaktindeBildirim && erkenDakika > 0) {
          final tamVakitZamani = DateTime(now.year, now.month, now.day, saat, dakika);
          if (tamVakitZamani.isAfter(now)) {
            await _scheduleNotification(
              id: i + 10, // 10-16 arası ID (vaktinde bildirimler için)
              title: '${_vakitTurkce[vakitKey]} Vakti Girdi',
              body: '${_vakitTurkce[vakitKey]} vakti girdi. Hayırlı ibadetler!',
              scheduledTime: tamVakitZamani,
              soundAsset: sesDosyasi,
            );
            debugPrint('✅ $vakitKey TAM VAKİT bildirimi zamanlandı: $saat:${dakika.toString().padLeft(2, '0')}');
          }
        }
      }

      debugPrint('🔔 Tüm vakit bildirimleri zamanlandı');
    } catch (e) {
      debugPrint('❌ Bildirim zamanlama hatası: $e');
    }
  }

  /// Tek bir bildirim zamanla
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundAsset,
  }) async {
    // Ses kaynağı adını al
    final soundResourceName = _getSoundResourceName(soundAsset);
    final channelId = 'vakit_scheduled_$soundResourceName';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Vakit Bildirimleri',
      channelDescription: 'Namaz vakitleri için zamanlanmış bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundResourceName),
      enableVibration: true,
      enableLights: true,
      showWhen: true,
      when: scheduledTime.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'vakit_$id',
    );
  }

  /// Tüm zamanlanmış bildirimleri iptal et
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('🗑️ Tüm zamanlanmış bildirimler iptal edildi');
  }

  /// Belirli bir vaktin bildirimini iptal et
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Ses dosyası adını Android raw kaynağı adına dönüştür
  static String _getSoundResourceName(String? soundAsset) {
    if (soundAsset == null || soundAsset.isEmpty) return 'ding_dong';
    
    String name = soundAsset.toLowerCase();
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }
    
    // Android resource adı için geçersiz karakterleri temizle
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    
    // Özel eşlemeler
    if (name == '2015_best') name = 'best';
    
    return name;
  }

  /// Yarının bildirimlerini zamanla (gece yarısında çağrılacak)
  static Future<void> scheduleNextDayNotifications() async {
    // Yarın için bildirimleri zamanla
    await scheduleAllPrayerNotifications();
  }
}
