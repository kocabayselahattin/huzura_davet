import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';
import 'alarm_service.dart';

/// Günlük içerik bildirimleri servisi
/// Her gün belirli saatlerde günün ayeti, hadisi ve duasını bildirim olarak gönderir
/// AlarmManager kullanır - uygulama kapalı olsa bile çalışır
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

      // Notification plugin'i başlat
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '🔔 Günlük içerik bildirimine tıklandı: ${response.payload}',
          );
        },
      );

      // Android notification channel oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Bildirim izni kontrolü ve isteği
        final hasPermission =
            await androidImplementation.areNotificationsEnabled() ?? false;
        debugPrint('📱 Günlük içerik bildirim izni: $hasPermission');

        if (!hasPermission) {
          debugPrint('⚠️ Günlük içerik bildirim izni verilmemiş, isteniyor...');
          await androidImplementation.requestNotificationsPermission();
        }

        // Exact alarm izni kontrolü
        final canScheduleExact =
            await androidImplementation.canScheduleExactNotifications() ??
            false;
        debugPrint('⏰ Exact alarm izni: $canScheduleExact');

        if (!canScheduleExact) {
          debugPrint('⚠️ Exact alarm izni verilmemiş, isteniyor...');
          await androidImplementation.requestExactAlarmsPermission();
        }

        // Ses ayarını al
        final soundFile = await getDailyContentNotificationSound();
        final soundName = soundFile.replaceAll('.mp3', '');

        // Eski kanalları sil (ses değişikliği için gerekli)
        try {
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel',
          );
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel_v2',
          );
          debugPrint('🗑️ Eski günlük içerik kanalları silindi');
        } catch (e) {
          debugPrint('⚠️ Kanal silinirken hata (normal olabilir): $e');
        }

        // Günlük içerik kanalı oluştur
        final channel = AndroidNotificationChannel(
          'daily_content_channel_v3',
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

    // Gerçek içeriği hesapla - gün bazlı
    final dayOfYear = scheduledDate
        .difference(DateTime(scheduledDate.year, 1, 1))
        .inDays;
    String bodyText = '';

    if (title == 'todays_verse') {
      // Günün Ayeti - verses listesinden al
      final versesList = languageService['verses'];
      if (versesList is List && versesList.isNotEmpty) {
        final index = dayOfYear % versesList.length;
        final verse = versesList[index];
        if (verse is Map) {
          final text = verse['text']?.toString() ?? '';
          final source = verse['source']?.toString() ?? '';
          bodyText = '$text\n📖 $source';
        }
      }
      if (bodyText.isEmpty) {
        bodyText =
            'Şüphesiz namaz, hayâsızlıktan ve kötülükten alıkoyar.\n📖 Ankebût, 45';
      }
    } else if (title == 'todays_hadith') {
      // Günün Hadisi - hadiths listesinden al
      final hadithsList = languageService['hadiths'];
      if (hadithsList is List && hadithsList.isNotEmpty) {
        final index = (dayOfYear + 14) % hadithsList.length;
        final hadith = hadithsList[index];
        if (hadith is Map) {
          final text = hadith['text']?.toString() ?? '';
          final source = hadith['source']?.toString() ?? '';
          bodyText = '$text\n📿 $source';
        }
      }
      if (bodyText.isEmpty) {
        bodyText =
            'Ameller niyetlere göredir. Herkesin niyeti ne ise eline geçecek odur.\n📿 Buhârî, Müslim';
      }
    } else if (title == 'todays_dua') {
      // Günün Duası - prayers listesinden al
      final prayersList = languageService['prayers'];
      if (prayersList is List && prayersList.isNotEmpty) {
        final index = (dayOfYear + 7) % prayersList.length;
        final prayer = prayersList[index];
        if (prayer is Map) {
          final text = prayer['text']?.toString() ?? '';
          final source = prayer['source']?.toString() ?? '';
          bodyText = '$text\n🤲 $source';
        }
      }
      if (bodyText.isEmpty) {
        bodyText =
            'Rabbim! Bana, ana-babama ve müminlere mağfiret et.\n🤲 İbrâhîm, 41';
      }
    } else {
      bodyText = languageService[body] ?? body;
    }

    // Ses ayarını al
    final soundFile = await getDailyContentNotificationSound();

    // AlarmManager kullanarak zamanla (vakit alarmları gibi kesin çalışır)
    final success = await AlarmService.scheduleDailyContentAlarm(
      notificationId: id,
      title: titleText,
      body: bodyText,
      triggerAtMillis: scheduledDate.millisecondsSinceEpoch,
      soundFile: soundFile,
    );

    if (success) {
      debugPrint(
        '📅 Günlük içerik AlarmManager ile zamanlandı: $titleText - ${scheduledDate.day}/${scheduledDate.month} ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')} (ID: $id)',
      );
    } else {
      debugPrint('❌ Günlük içerik zamanlama başarısız: $titleText (ID: $id)');
    }
  }

  /// Tüm günlük içerik bildirimlerini iptal et
  static Future<void> cancelAllDailyContentNotifications() async {
    // AlarmManager ile zamanlanmış bildirimleri iptal et
    await AlarmService.cancelAllDailyContentAlarms();
    debugPrint('🚫 Günlük içerik bildirimleri iptal edildi (AlarmManager)');
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

  /// Test bildirimi gönder (hemen)
  static Future<void> sendTestNotification(String type) async {
    if (!_initialized) {
      await initialize();
    }

    final languageService = LanguageService();
    await languageService.load();

    String title;
    String body;
    int id;

    // Bugünün içeriğini hesapla
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    switch (type) {
      case 'verse':
        title = languageService['todays_verse'] ?? 'Günün Ayeti';
        // Günün gerçek ayetini al
        final versesList = languageService['verses'];
        if (versesList is List && versesList.isNotEmpty) {
          final index = dayOfYear % versesList.length;
          final verse = versesList[index];
          if (verse is Map) {
            final text = verse['text']?.toString() ?? '';
            final source = verse['source']?.toString() ?? '';
            body = '$text\n📖 $source';
          } else {
            body =
                'Şüphesiz namaz, hayâsızlıktan ve kötülükten alıkoyar.\n📖 Ankebût, 45';
          }
        } else {
          body =
              'Şüphesiz namaz, hayâsızlıktan ve kötülükten alıkoyar.\n📖 Ankebût, 45';
        }
        id = 9000;
        break;
      case 'hadith':
        title = languageService['todays_hadith'] ?? 'Günün Hadisi';
        // Günün gerçek hadisini al
        final hadithsList = languageService['hadiths'];
        if (hadithsList is List && hadithsList.isNotEmpty) {
          final index = (dayOfYear + 14) % hadithsList.length;
          final hadith = hadithsList[index];
          if (hadith is Map) {
            final text = hadith['text']?.toString() ?? '';
            final source = hadith['source']?.toString() ?? '';
            body = '$text\n📿 $source';
          } else {
            body =
                'Ameller niyetlere göredir. Herkesin niyeti ne ise eline geçecek odur.\n📿 Buhârî, Müslim';
          }
        } else {
          body =
              'Ameller niyetlere göredir. Herkesin niyeti ne ise eline geçecek odur.\n📿 Buhârî, Müslim';
        }
        id = 9001;
        break;
      case 'prayer':
        title = languageService['todays_dua'] ?? 'Günün Duası';
        // Günün gerçek duasını al
        final prayersList = languageService['prayers'];
        if (prayersList is List && prayersList.isNotEmpty) {
          final index = (dayOfYear + 7) % prayersList.length;
          final prayer = prayersList[index];
          if (prayer is Map) {
            final text = prayer['text']?.toString() ?? '';
            final source = prayer['source']?.toString() ?? '';
            body = '$text\n🤲 $source';
          } else {
            body =
                'Rabbim! Bana, ana-babama ve müminlere mağfiret et.\n🤲 İbrâhîm, 41';
          }
        } else {
          body =
              'Rabbim! Bana, ana-babama ve müminlere mağfiret et.\n🤲 İbrâhîm, 41';
        }
        id = 9002;
        break;
      default:
        return;
    }

    final soundFile = await getDailyContentNotificationSound();
    final soundName = soundFile.replaceAll('.mp3', '');

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_content_channel_v3',
      'Günlük İçerik',
      channelDescription: 'Günün ayeti, hadisi ve duası bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ticker: 'Günlük içerik',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // BigText style - tam içerik göster
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Huzur Vakti',
        htmlFormatSummaryText: false,
      ),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidPlatformChannelSpecifics,
      ),
      payload: null,
    );

    debugPrint('🔔 Test bildirimi gönderildi: $title');
  }
}

