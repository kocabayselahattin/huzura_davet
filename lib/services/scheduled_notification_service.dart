import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'alarm_service.dart';

/// Zamanlanmış bildirim servisi - Uygulama kapalıyken bile vakit bildirimlerini gönderir
class ScheduledNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _dailyScheduleTimer;
  static DateTime? _lastScheduleDate;

  // Vakit isimleri
  static const List<String> _vakitler = [
    'Imsak',
    'Gunes',
    'Ogle',
    'Ikindi',
    'Aksam',
    'Yatsi',
  ];

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

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Bildirime tıklandı: ${response.payload}');
      },
    );

    // Android 13+ için bildirim izni kontrolü
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      final hasPermission =
          await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Bildirim izni durumu: $hasPermission');

      if (!hasPermission) {
        debugPrint('⚠️ Bildirim izni verilmemiş! İzin isteniyor...');
        final granted =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        debugPrint('📱 Bildirim izni sonucu: $granted');

        if (!granted) {
          debugPrint('❌ Bildirim izni reddedildi! Bildirimler çalışmayacak.');
        }
      }

      // Exact alarm izni kontrolü (Android 12+)
      final canScheduleExact =
          await androidImplementation.canScheduleExactNotifications() ?? false;
      debugPrint('⏰ Exact alarm izni: $canScheduleExact');

      if (!canScheduleExact) {
        debugPrint('⚠️ Exact alarm izni yok! İzin isteniyor...');
        final granted =
            await androidImplementation.requestExactAlarmsPermission() ?? false;
        debugPrint('⏰ Exact alarm izni sonucu: $granted');
      }
    }

    _initialized = true;
    debugPrint('✅ Zamanlanmış bildirim servisi başlatıldı');

    // Günlük zamanlama kontrolü başlat
    _startDailyScheduleCheck();
  }

  /// Günlük bildirimleri kontrol eden timer başlat
  static void _startDailyScheduleCheck() {
    _dailyScheduleTimer?.cancel();
    // Her dakika kontrol et
    _dailyScheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Gün değiştiyse veya hiç zamanlanmadıysa
      if (_lastScheduleDate == null || _lastScheduleDate!.isBefore(today)) {
        debugPrint('📅 Yeni gün başladı, bildirimler yeniden zamanlanıyor...');
        await scheduleAllPrayerNotifications();
        _lastScheduleDate = today;
      }
    });
  }

  /// Tüm vakit bildirimlerini zamanla
  static Future<void> scheduleAllPrayerNotifications() async {
    try {
      debugPrint('🔔 Tüm vakit bildirimleri zamanlanıyor...');

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

      debugPrint('📋 Alınan vakitler: $vakitler');

      // Kullanıcı ayarlarını yükle
      final prefs = await SharedPreferences.getInstance();
      int scheduledCount = 0;

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
        if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
          debugPrint('⚠️ $vakitKey saati boş veya geçersiz: $vakitSaati');
          continue;
        }

        // Erken bildirim süresi (dakika)
        final erkenDakika = prefs.getInt('erken_$vakitKeyLower') ?? 0;

        // Ses dosyası
        final sesDosyasi =
            prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'Ding_Dong.mp3';

        // Vakit saatini parse et
        final parts = vakitSaati.split(':');
        if (parts.length != 2) {
          debugPrint('⚠️ $vakitKey saat formatı hatalı: $vakitSaati');
          continue;
        }

        final saat = int.tryParse(parts[0]);
        final dakika = int.tryParse(parts[1]);
        if (saat == null || dakika == null) {
          debugPrint('⚠️ $vakitKey saat parse edilemedi: $vakitSaati');
          continue;
        }

        // Bildirim zamanını hesapla
        final now = DateTime.now();
        var bildirimZamani = DateTime(
          now.year,
          now.month,
          now.day,
          saat,
          dakika,
        );

        // Erken bildirim süresi varsa çıkar
        if (erkenDakika > 0) {
          bildirimZamani = bildirimZamani.subtract(
            Duration(minutes: erkenDakika),
          );
        }

        // Eğer zaman geçmişse, bildirimi atla (yarına zamanla)
        if (bildirimZamani.isBefore(now)) {
          // Yarın için zamanla
          bildirimZamani = bildirimZamani.add(const Duration(days: 1));
          debugPrint(
            '⏰ $vakitKey vakti geçmiş, yarına zamanlanıyor: ${bildirimZamani.hour}:${bildirimZamani.minute.toString().padLeft(2, '0')}',
          );
        }

        // Bildirimi zamanla
        await _scheduleNotification(
          id: i + 1, // 1-6 arası ID
          title:
              '${_vakitTurkce[vakitKey]} Vakti ${erkenDakika > 0 ? "Yaklaşıyor" : "Girdi"}',
          body: erkenDakika > 0
              ? '${_vakitTurkce[vakitKey]} vaktine $erkenDakika dakika kaldı'
              : '${_vakitTurkce[vakitKey]} vakti girdi. Hayırlı ibadetler!',
          scheduledTime: bildirimZamani,
          soundAsset: sesDosyasi,
        );

        scheduledCount++;
        debugPrint(
          '✅ $vakitKey bildirimi zamanlandı: ${bildirimZamani.day}/${bildirimZamani.month} ${bildirimZamani.hour}:${bildirimZamani.minute.toString().padLeft(2, '0')}',
        );

        // 🔔 ALARM: Alarm her zaman TAM VAKİT zamanında çalmalı (erken bildirimden bağımsız)
        final alarmAcik = prefs.getBool('alarm_$vakitKeyLower') ?? false;
        if (alarmAcik) {
          // Alarm için tam vakit zamanını hesapla
          var alarmZamani = DateTime(
            now.year,
            now.month,
            now.day,
            saat,
            dakika,
          );
          
          // Eğer vakit geçtiyse yarına zamanla
          if (alarmZamani.isBefore(now)) {
            alarmZamani = alarmZamani.add(const Duration(days: 1));
          }
          
          final alarmId = AlarmService.generateAlarmId(
            vakitKeyLower,
            alarmZamani,
          );
          await AlarmService.scheduleAlarm(
            prayerName: _vakitTurkce[vakitKey] ?? vakitKey,
            triggerAtMillis: alarmZamani.millisecondsSinceEpoch,
            soundPath: sesDosyasi,
            useVibration: true,
            alarmId: alarmId,
          );
          debugPrint(
            '⏰ $vakitKey ALARMI zamanlandı: ${alarmZamani.day}/${alarmZamani.month} ${alarmZamani.hour}:${alarmZamani.minute.toString().padLeft(2, '0')}',
          );
        }

        // Erken bildirim varsa, ayrıca vaktinde de bildirim gönder (vakit girdiğinde)
        if (erkenDakika > 0) {
          var tamVakitZamani = DateTime(
            now.year,
            now.month,
            now.day,
            saat,
            dakika,
          );

          if (tamVakitZamani.isBefore(now)) {
            tamVakitZamani = tamVakitZamani.add(const Duration(days: 1));
          }

          await _scheduleNotification(
            id: i + 10, // 10-16 arası ID (vaktinde bildirimler için)
            title: '${_vakitTurkce[vakitKey]} Vakti Girdi',
            body: '${_vakitTurkce[vakitKey]} vakti girdi. Hayırlı ibadetler!',
            scheduledTime: tamVakitZamani,
            soundAsset: sesDosyasi,
          );
          scheduledCount++;
          debugPrint(
            '✅ $vakitKey TAM VAKİT bildirimi zamanlandı: ${tamVakitZamani.day}/${tamVakitZamani.month} $saat:${dakika.toString().padLeft(2, '0')}',
          );
        }
      }

      debugPrint('🔔 Toplam $scheduledCount bildirim zamanlandı');
    } catch (e, stackTrace) {
      debugPrint('❌ Bildirim zamanlama hatası: $e');
      debugPrint('📋 Stack trace: $stackTrace');
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
    try {
      // Ses kaynağı adını al
      final soundResourceName = _getSoundResourceName(soundAsset);
      final channelId = 'vakit_notification_channel';

      // Android implementation'ı al ve channel oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Ana bildirim kanalı oluştur (Android ses değişimi kısıtlaması nedeniyle tek kanal)
        final channel = AndroidNotificationChannel(
          channelId,
          'Namaz Vakti Bildirimleri',
          description: 'Namaz vakitleri için zamanlanmış bildirimler',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(channel);
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Namaz Vakti Bildirimleri',
        channelDescription: 'Namaz vakitleri için zamanlanmış bildirimler',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
        enableVibration: true,
        enableLights: true,
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: false,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(body),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'vakit_$id',
      );

      debugPrint(
        '⏰ Bildirim zamanlandı: ID=$id, Zaman=${scheduledTime.day}/${scheduledTime.month} ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}, Ses=$soundResourceName',
      );
    } catch (e) {
      debugPrint('❌ Bildirim zamanlama hatası (ID=$id): $e');
    }
  }

  /// Tüm zamanlanmış bildirimleri ve alarmları iptal et
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    await AlarmService.cancelAllAlarms();
    debugPrint('🗑️ Tüm zamanlanmış bildirimler ve alarmlar iptal edildi');
  }

  /// Belirli bir vaktin bildirimini iptal et
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Zamanlanmış bildirimlerin listesini al (debug için)
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Hemen bir test bildirimi gönder
  static Future<void> sendTestNotification() async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Bildirimleri',
        channelDescription: 'Test amaçlı bildirimler',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        999,
        '🧪 Test Bildirimi',
        'Bildirim sistemi çalışıyor! ${DateTime.now().toString().substring(11, 19)}',
        notificationDetails,
      );
      debugPrint('✅ Test bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Test bildirimi gönderilemedi: $e');
    }
  }

  /// Kilit ekranı testi için 5 saniye sonra bildirim gönder
  /// Bu sayede kullanıcı telefonu kilitleyip bildirimin gelip gelmediğini test edebilir
  static Future<void> sendLockScreenTestNotification() async {
    try {
      final scheduledTime = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5));

      final androidDetails = AndroidNotificationDetails(
        'prayer_notifications',
        'Vakit Bildirimleri',
        channelDescription: 'Namaz vakti bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility:
            NotificationVisibility.public, // Kilit ekranında tam görünür
        ticker: 'Kilit Ekranı Test Bildirimi',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        998,
        '🔒 Kilit Ekranı Testi',
        '5 saniye sonra zamanlandı - Kilit ekranında görüyorsan bildirimler çalışıyor!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('✅ Kilit ekranı test bildirimi 5 saniye sonra zamanlandı');
    } catch (e) {
      debugPrint('❌ Kilit ekranı test bildirimi gönderilemedi: $e');
    }
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
