import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';

/// Günlük içerik bildirimleri servisi
/// Her gün belirli saatlerde günün ayeti, hadisi ve duasını bildirim olarak gönderir
class DailyContentNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Bildirim saatleri
  static const int verseHour = 8; // Sabah 08:00 - Günün Ayeti
  static const int hadithHour = 13; // Öğle 13:00 - Günün Hadisi
  static const int prayerHour = 20; // Akşam 20:00 - Günün Duası

  // Bildirim ID'leri
  static const int verseNotificationId = 1000;
  static const int hadithNotificationId = 1001;
  static const int prayerNotificationId = 1002;

  // Varsayılan ses dosyası
  static const String defaultNotificationSound = 'ding_dong';

  /// Günlük içerik bildirim sesini ayarla
  static Future<void> setDailyContentNotificationSound(
    String soundFileName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_content_notification_sound', soundFileName);
    debugPrint('✅ Günlük içerik bildirim sesi ayarlandı: $soundFileName');

    // Servisi yeniden başlat (kanal ses ayarını güncellemek için)
    _initialized = false;
    await initialize();

    // Bildirimleri yeniden zamanla
    await scheduleDailyContentNotifications();
  }

  /// Günlük içerik bildirim sesini al
  static Future<String> getDailyContentNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('daily_content_notification_sound') ??
        defaultNotificationSound;
  }

  /// Servisi başlat
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Timezone verilerini yükle
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      debugPrint('🕐 Timezone başlatıldı: ${tz.local.name}');

      // Android notification channel oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Ses ayarını al
        final soundFile = await getDailyContentNotificationSound();
        final soundName = soundFile.replaceAll('.mp3', '');

        // Eski kanalı sil ve yeniden oluştur (ses değişikliği için gerekli)
        try {
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel',
          );
          debugPrint('🗑️ Eski günlük içerik kanalı silindi');
        } catch (e) {
          debugPrint('⚠️ Kanal silinirken hata (normal olabilir): $e');
        }

        // Günlük içerik kanalı oluştur
        final channel = AndroidNotificationChannel(
          'daily_content_channel',
          'Günlük İçerik',
          description: 'Günün ayeti, hadisi ve duası bildirimleri',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundName),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        debugPrint(
          '✅ Günlük içerik bildirim kanalı oluşturuldu (ses: $soundName)',
        );
      }

      _initialized = true;
      debugPrint('✅ Günlük içerik bildirim servisi başlatıldı');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirim servisi başlatılamadı: $e');
    }
  }

  /// Günlük bildirimleri zamanla
  static Future<void> scheduleDailyContentNotifications() async {
    debugPrint('📱 Günlük içerik bildirimleri zamanlanıyor...');

    if (!_initialized) {
      debugPrint('🔧 Servis henüz başlatılmamış, initialize ediliyor...');
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('daily_content_notifications_enabled') ?? true;
    debugPrint('🔍 daily_content_notifications_enabled: $enabled');

    if (!enabled) {
      debugPrint('⏸️ Günlük içerik bildirimleri devre dışı');
      await cancelAllDailyContentNotifications();
      return;
    }

    try {
      debugPrint('🗑️ Mevcut günlük içerik bildirimleri iptal ediliyor...');
      // Mevcut bildirimleri iptal et
      await cancelAllDailyContentNotifications();

      // 7 günlük bildirimler zamanla (her gün için ayrı)
      final now = tz.TZDateTime.now(tz.local);
      int scheduledCount = 0;

      for (int day = 0; day < 7; day++) {
        final targetDate = now.add(Duration(days: day));

        // Günün Ayeti - Sabah 08:00
        final verseTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          verseHour,
          0,
          0,
        );
        if (verseTime.isAfter(now)) {
          await _scheduleNotification(
            id: verseNotificationId + day * 10,
            title: 'todays_verse',
            body: 'daily_verse_notification_desc',
            scheduledDate: verseTime,
          );
          scheduledCount++;
        }

        // Günün Hadisi - Öğle 13:00
        final hadithTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hadithHour,
          0,
          0,
        );
        if (hadithTime.isAfter(now)) {
          await _scheduleNotification(
            id: hadithNotificationId + day * 10,
            title: 'todays_hadith',
            body: 'daily_hadith_notification_desc',
            scheduledDate: hadithTime,
          );
          scheduledCount++;
        }

        // Günün Duası - Akşam 20:00
        final prayerTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          prayerHour,
          0,
          0,
        );
        if (prayerTime.isAfter(now)) {
          await _scheduleNotification(
            id: prayerNotificationId + day * 10,
            title: 'todays_dua',
            body: 'daily_prayer_notification_desc',
            scheduledDate: prayerTime,
          );
          scheduledCount++;
        }
      }

      debugPrint(
        '✅ Günlük içerik bildirimleri zamanlandı ($scheduledCount adet):',
      );
      debugPrint('   📖 Günün Ayeti: Her gün $verseHour:00');
      debugPrint('   📿 Günün Hadisi: Her gün $hadithHour:00');
      debugPrint('   🤲 Günün Duası: Her gün $prayerHour:00');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirimleri zamanlanamadı: $e');
    }
  }

  /// Bildirim zamanla (7 günlük sistem)
  static Future<void> _scheduleNotification({
    required int id,
    required String title, // Dil anahtarı
    required String body, // Dil anahtarı
    required tz.TZDateTime scheduledDate,
  }) async {
    // Dil servisinden metinleri al
    final languageService = LanguageService();
    await languageService.load();

    final titleText = languageService[title] ?? title;
    final bodyText = languageService[body] ?? body;

    // Ses ayarını al
    final soundFile = await getDailyContentNotificationSound();
    final soundName = soundFile.replaceAll('.mp3', '');

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_content_channel_v2', // Yeni channel ID - eski ayarları geçersiz kılar
      'Günlük İçerik',
      channelDescription: 'Günün ayeti, hadisi ve duası bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
      ticker: 'Günlük içerik',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: titleText,
      body: bodyText,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '📅 Bildirim zamanlandı: $titleText - ${scheduledDate.day}/${scheduledDate.month} ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')} (ID: $id)',
    );
  }

  /// Tüm günlük içerik bildirimlerini iptal et
  static Future<void> cancelAllDailyContentNotifications() async {
    // 7 günlük tüm bildirimleri iptal et
    for (int day = 0; day < 7; day++) {
      await _notificationsPlugin.cancel(id: verseNotificationId + day * 10);
      await _notificationsPlugin.cancel(id: hadithNotificationId + day * 10);
      await _notificationsPlugin.cancel(id: prayerNotificationId + day * 10);
    }
    debugPrint('🚫 Günlük içerik bildirimleri iptal edildi');
  }

  /// Günlük içerik bildirimlerini aç/kapat
  static Future<void> setDailyContentNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_content_notifications_enabled', enabled);

    if (enabled) {
      await scheduleDailyContentNotifications();
    } else {
      await cancelAllDailyContentNotifications();
    }
  }

  /// Günlük içerik bildirimleri aktif mi?
  static Future<bool> isDailyContentNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('daily_content_notifications_enabled') ?? true;
  }

  /// Test bildirimi gönder (hemen)
  static Future<void> sendTestNotification(String type) async {
    if (!_initialized) {
      await initialize();
    }

    final languageService = LanguageService();
    await languageService.load();

    String title, body;
    int id;

    switch (type) {
      case 'verse':
        title = languageService['todays_verse'] ?? 'Günün Ayeti';
        body = 'Test bildirimi - Bu günün ayeti bildirimi örneğidir';
        id = 9000;
        break;
      case 'hadith':
        title = languageService['todays_hadith'] ?? 'Günün Hadisi';
        body = 'Test bildirimi - Bu günün hadisi bildirimi örneğidir';
        id = 9001;
        break;
      case 'prayer':
        title = languageService['todays_dua'] ?? 'Günün Duası';
        body = 'Test bildirimi - Bu günün duası bildirimi örneğidir';
        id = 9002;
        break;
      default:
        return;
    }

    // Ses ayarını al
    final soundFile = await getDailyContentNotificationSound();
    final soundName = soundFile.replaceAll('.mp3', '');

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_content_channel',
      'Günlük İçerik',
      channelDescription: 'Günün ayeti, hadisi ve duası bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ticker: 'Test bildirimi',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );

    debugPrint('🔔 Test bildirimi gönderildi: $title');
  }
}
