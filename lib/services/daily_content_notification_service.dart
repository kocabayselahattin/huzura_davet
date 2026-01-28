import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
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
  static const int verseHour = 8;    // Sabah 08:00 - Günün Ayeti
  static const int hadithHour = 13;  // Öğle 13:00 - Günün Hadisi  
  static const int prayerHour = 20;  // Akşam 20:00 - Günün Duası

  // Bildirim ID'leri
  static const int verseNotificationId = 1000;
  static const int hadithNotificationId = 1001;
  static const int prayerNotificationId = 1002;

  // Varsayılan ses dosyası
  static const String defaultNotificationSound = 'ding_dong';

  /// Günlük içerik bildirim sesini ayarla
  static Future<void> setDailyContentNotificationSound(String soundFileName) async {
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
    return prefs.getString('daily_content_notification_sound') ?? defaultNotificationSound;
  }

  /// Servisi başlat
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Android notification channel oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Ses ayarını al
        final soundFile = await getDailyContentNotificationSound();
        final soundName = soundFile.replaceAll('.mp3', '');
        
        // Eski kanalı sil ve yeniden oluştur (ses değişikliği için gerekli)
        try {
          await androidImplementation.deleteNotificationChannel(channelId: 'daily_content_channel');
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
        debugPrint('✅ Günlük içerik bildirim kanalı oluşturuldu (ses: $soundName)');
      }

      _initialized = true;
      debugPrint('✅ Günlük içerik bildirim servisi başlatıldı');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirim servisi başlatılamadı: $e');
    }
  }

  /// Günlük bildirimleri zamanla
  static Future<void> scheduleDailyContentNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('daily_content_notifications_enabled') ?? true;

    if (!enabled) {
      debugPrint('⏸️ Günlük içerik bildirimleri devre dışı');
      await cancelAllDailyContentNotifications();
      return;
    }

    try {
      // Mevcut bildirimleri iptal et
      await cancelAllDailyContentNotifications();

      // Her bildirim için zamanlama yap
      await _scheduleVerseNotification();
      await _scheduleHadithNotification();
      await _schedulePrayerNotification();

      debugPrint('✅ Günlük içerik bildirimleri zamanlandı:');
      debugPrint('   📖 Günün Ayeti: Her gün $verseHour:00');
      debugPrint('   📿 Günün Hadisi: Her gün $hadithHour:00');
      debugPrint('   🤲 Günün Duası: Her gün $prayerHour:00');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirimleri zamanlanamadı: $e');
    }
  }

  /// Günün ayeti bildirimini zamanla
  static Future<void> _scheduleVerseNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      verseHour,
      0,
      0,
    );

    // Eğer saat geçmişse yarına ayarla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final languageService = LanguageService();
    await languageService.load();
    
    final title = languageService['todays_verse'] ?? 'Günün Ayeti';
    final body = languageService['daily_verse_notification_desc'] ?? 
                 'Bugünün ayetini okumak için tıklayın';

    await _scheduleNotification(
      id: verseNotificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  /// Günün hadisi bildirimini zamanla
  static Future<void> _scheduleHadithNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hadithHour,
      0,
      0,
    );

    // Eğer saat geçmişse yarına ayarla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final languageService = LanguageService();
    await languageService.load();
    
    final title = languageService['todays_hadith'] ?? 'Günün Hadisi';
    final body = languageService['daily_hadith_notification_desc'] ?? 
                 'Bugünün hadisini okumak için tıklayın';

    await _scheduleNotification(
      id: hadithNotificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  /// Günün duası bildirimini zamanla
  static Future<void> _schedulePrayerNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      prayerHour,
      0,
      0,
    );

    // Eğer saat geçmişse yarına ayarla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final languageService = LanguageService();
    await languageService.load();
    
    final title = languageService['todays_dua'] ?? 'Günün Duası';
    final body = languageService['daily_prayer_notification_desc'] ?? 
                 'Bugünün duasını okumak için tıklayın';

    await _scheduleNotification(
      id: prayerNotificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  /// Bildirim zamanla (her gün tekrar eden)
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
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
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ticker: 'Günlük içerik',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte
    );

    debugPrint('📅 Bildirim zamanlandı: $title - ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}');
  }

  /// Tüm günlük içerik bildirimlerini iptal et
  static Future<void> cancelAllDailyContentNotifications() async {
    await _notificationsPlugin.cancel(id: verseNotificationId);
    await _notificationsPlugin.cancel(id: hadithNotificationId);
    await _notificationsPlugin.cancel(id: prayerNotificationId);
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
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
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
