import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';
import 'alarm_service.dart';
import 'early_reminder_service.dart';

/// Günlük içerik alarmları servisi
/// Her gün belirli saatlerde günün ayeti, hadisi ve duasını alarm olarak gönderir
/// AlarmManager kullanır - uygulama kapalı olsa bile çalışır
class DailyContentNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Varsayilan saatler
  static const String _defaultVerseTime = '08:00';
  static const String _defaultHadithTime = '13:00';
  static const String _defaultPrayerTime = '20:00';

  static const String _verseTimeKey = 'daily_content_verse_time';
  static const String _hadithTimeKey = 'daily_content_hadith_time';
  static const String _prayerTimeKey = 'daily_content_prayer_time';

  // Bildirim ID'leri
  static const int verseNotificationId = 1000;
  static const int hadithNotificationId = 1001;
  static const int prayerNotificationId = 1002;

  // Varsayılan ses dosyası
  static const String defaultNotificationSound = 'ding_dong';

  /// Günlük içerik alarm sesini ayarla
  static Future<void> setDailyContentNotificationSound(
    String soundFileName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_content_notification_sound', soundFileName);
    debugPrint('✅ Günlük içerik alarm sesi ayarlandı: $soundFileName');

    // Servisi yeniden başlat (kanal ses ayarını güncellemek için)
    _initialized = false;
    await initialize();

    // Alarmlari yeniden zamanla
    await scheduleDailyContentNotifications();
  }

  /// Günlük içerik alarm sesini al
  static Future<String> getDailyContentNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('daily_content_notification_sound') ??
        defaultNotificationSound;
  }

  /// Günlük içerik alarm saatlerini ayarla
  static Future<void> setDailyContentNotificationTimes({
    required String verseTime,
    required String hadithTime,
    required String prayerTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verseTimeKey, verseTime);
    await prefs.setString(_hadithTimeKey, hadithTime);
    await prefs.setString(_prayerTimeKey, prayerTime);

    _initialized = false;
    await initialize();
    await scheduleDailyContentNotifications();
  }

  /// Gunluk icerik alarm ayarlarini topluca guncelle
  static Future<void> setDailyContentNotificationSettings({
    required bool enabled,
    required String soundFileName,
    required String verseTime,
    required String hadithTime,
    required String prayerTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_content_notifications_enabled', enabled);
    await prefs.setString('daily_content_notification_sound', soundFileName);
    await prefs.setString(_verseTimeKey, verseTime);
    await prefs.setString(_hadithTimeKey, hadithTime);
    await prefs.setString(_prayerTimeKey, prayerTime);

    _initialized = false;
    await initialize();
    if (enabled) {
      await scheduleDailyContentNotifications();
    } else {
      await cancelAllDailyContentNotifications();
    }
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

        // Ses ayarını al ve normalize et
        final soundFileRaw = await getDailyContentNotificationSound();
        final soundName = EarlyReminderService.normalizeSoundName(soundFileRaw);

        // Eski kanalları sil (ses değişikliği için gerekli)
        try {
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel',
          );
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel_v2',
          );
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel_v3',
          );
          await androidImplementation.deleteNotificationChannel(
            channelId: 'daily_content_channel_v4',
          );
          debugPrint('🗑️ Eski günlük içerik kanalları silindi');
        } catch (e) {
          debugPrint('⚠️ Kanal silinirken hata (normal olabilir): $e');
        }

        // Günlük içerik kanalı oluştur
        final channel = AndroidNotificationChannel(
          'daily_content_channel_v4',
          'Günlük İçerik',
          description: 'Günün ayeti, hadisi ve duası alarmlari',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundName),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        debugPrint(
          '✅ Günlük içerik alarm kanalı oluşturuldu (ses: $soundName)',
        );
      }

      _initialized = true;
      debugPrint('✅ Günlük içerik bildirim servisi başlatıldı');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirim servisi başlatılamadı: $e');
    }
  }

  /// Günlük alarmlari zamanla
  static Future<void> scheduleDailyContentNotifications() async {
    debugPrint('📱 Günlük içerik alarmlari zamanlaniyor...');

    if (!_initialized) {
      debugPrint('🔧 Servis henüz başlatılmamış, initialize ediliyor...');
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('daily_content_notifications_enabled') ?? true;
    debugPrint('🔍 daily_content_notifications_enabled: $enabled');

    if (!enabled) {
      debugPrint('⏸️ Günlük içerik alarmlari devre disi');
      await cancelAllDailyContentNotifications();
      return;
    }

    try {
      debugPrint('🗑️ Mevcut günlük içerik alarmlari iptal ediliyor...');
      // Mevcut alarmlari iptal et
      await cancelAllDailyContentNotifications();

      // 7 gunluk alarmlar zamanla (her gun icin ayri)
      final times = await _getDailyContentTimes();
      final verseTimeParts = times['verse']!;
      final hadithTimeParts = times['hadith']!;
      final prayerTimeParts = times['prayer']!;
      final now = tz.TZDateTime.now(tz.local);
      int scheduledCount = 0;

      for (int day = 0; day < 7; day++) {
        final targetDate = now.add(Duration(days: day));

        // Gunun Ayeti
        final verseTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          verseTimeParts[0],
          verseTimeParts[1],
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

        // Gunun Hadisi
        final hadithTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hadithTimeParts[0],
          hadithTimeParts[1],
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

        // Gunun Duasi
        final prayerTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          prayerTimeParts[0],
          prayerTimeParts[1],
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
        '✅ Günlük içerik alarmlari zamanlandi ($scheduledCount adet):',
      );
      debugPrint(
        '   📖 Gunun Ayeti: Her gun ${times['verse']![0].toString().padLeft(2, '0')}:${times['verse']![1].toString().padLeft(2, '0')}',
      );
      debugPrint(
        '   📿 Gunun Hadisi: Her gun ${times['hadith']![0].toString().padLeft(2, '0')}:${times['hadith']![1].toString().padLeft(2, '0')}',
      );
      debugPrint(
        '   🤲 Gunun Duasi: Her gun ${times['prayer']![0].toString().padLeft(2, '0')}:${times['prayer']![1].toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('❌ Günlük içerik alarmlari zamanlanamadi: $e');
    }
  }

  static Future<Map<String, List<int>>> _getDailyContentTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final verse = prefs.getString(_verseTimeKey) ?? _defaultVerseTime;
    final hadith = prefs.getString(_hadithTimeKey) ?? _defaultHadithTime;
    final prayer = prefs.getString(_prayerTimeKey) ?? _defaultPrayerTime;

    return {
      'verse': _parseTimeParts(verse, _defaultVerseTime),
      'hadith': _parseTimeParts(hadith, _defaultHadithTime),
      'prayer': _parseTimeParts(prayer, _defaultPrayerTime),
    };
  }

  static List<int> _parseTimeParts(String value, String fallback) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return _parseTimeParts(fallback, fallback);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return _parseTimeParts(fallback, fallback);
    }
    return [hour, minute];
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

    // Ses ayarını al ve normalize et
    final soundFileRaw = await getDailyContentNotificationSound();
    final soundFile = EarlyReminderService.normalizeSoundName(soundFileRaw);

    debugPrint('🔊 Günlük içerik ses: raw=$soundFileRaw, normalized=$soundFile');

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

  /// Tum gunluk icerik alarmlarini iptal et
  static Future<void> cancelAllDailyContentNotifications() async {
    // AlarmManager ile zamanlanmış bildirimleri iptal et
    await AlarmService.cancelAllDailyContentAlarms();
    debugPrint('🚫 Günlük içerik alarmlari iptal edildi (AlarmManager)');
  }

  /// Gunluk icerik alarmlarini ac/kapat
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

    final soundFileRaw = await getDailyContentNotificationSound();
    final soundName = EarlyReminderService.normalizeSoundName(soundFileRaw);

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_content_channel_v4',
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

