import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';
import 'alarm_service.dart';
import 'gunluk_hadis_dua_service.dart';
import 'kuran_veri_service.dart';

/// Daily content alarm service.
/// Sends daily verse, hadith, and dua notifications at set times.
/// Uses AlarmManager to work when the app is closed.
class DailyContentNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Default times
  static const String _defaultVerseTime = '08:00';
  static const String _defaultHadithTime = '13:00';
  static const String _defaultPrayerTime = '20:00';
  static const String _defaultTahajjudTime = '03:00';

  static const String _verseTimeKey = 'daily_content_verse_time';
  static const String _hadithTimeKey = 'daily_content_hadith_time';
  static const String _prayerTimeKey = 'daily_content_prayer_time';
  static const String _tahajjudTimeKey = 'daily_content_tahajjud_time';

  // Notification IDs
  static const int verseNotificationId = 1000;
  static const int hadithNotificationId = 1001;
  static const int prayerNotificationId = 1002;
  static const int tahajjudNotificationId = 1003;

  // Default sound file
  static const String defaultNotificationSound = 'best';
  static const String _tahajjudSoundKey = 'daily_content_tahajjud_sound';
  static const String _tahajjudEnabledKey = 'daily_content_tahajjud_enabled';

  /// Set daily content alarm sound.
  static Future<void> setDailyContentNotificationSound(
    String soundFileName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_content_notification_sound', soundFileName);
    debugPrint('✅ Daily content alarm sound set: $soundFileName');

    // Restart service to update channel sound.
    _initialized = false;
    await initialize();

    // Reschedule alarms
    await scheduleDailyContentNotifications();
  }

  /// Get daily content alarm sound (sound ID).
  static Future<String> getDailyContentNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('daily_content_notification_sound') ??
        defaultNotificationSound;
  }

  /// Get tahajjud alarm sound (sound ID).
  static Future<String> getDailyTahajjudNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final tahajjudSound = prefs.getString(_tahajjudSoundKey);
    if (tahajjudSound != null && tahajjudSound.isNotEmpty) {
      return tahajjudSound;
    }
    return prefs.getString('daily_content_notification_sound') ??
        defaultNotificationSound;
  }

  /// Set daily content alarm times.
  static Future<void> setDailyContentNotificationTimes({
    required String verseTime,
    required String hadithTime,
    required String prayerTime,
    required String tahajjudTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verseTimeKey, verseTime);
    await prefs.setString(_hadithTimeKey, hadithTime);
    await prefs.setString(_prayerTimeKey, prayerTime);
    await prefs.setString(_tahajjudTimeKey, tahajjudTime);

    _initialized = false;
    await initialize();
    await scheduleDailyContentNotifications();
  }

  /// Update daily content alarm settings.
  static Future<void> setDailyContentNotificationSettings({
    required bool enabled,
    required bool tahajjudEnabled,
    required String soundFileName,
    required String tahajjudSoundFileName,
    required String verseTime,
    required String hadithTime,
    required String prayerTime,
    required String tahajjudTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_content_notifications_enabled', enabled);
    await prefs.setBool(_tahajjudEnabledKey, tahajjudEnabled);
    await prefs.setString('daily_content_notification_sound', soundFileName);
    await prefs.setString(_tahajjudSoundKey, tahajjudSoundFileName);
    await prefs.setString(_verseTimeKey, verseTime);
    await prefs.setString(_hadithTimeKey, hadithTime);
    await prefs.setString(_prayerTimeKey, prayerTime);
    await prefs.setString(_tahajjudTimeKey, tahajjudTime);

    _initialized = false;
    await initialize();
    if (enabled) {
      await scheduleDailyContentNotifications();
    } else {
      await cancelAllDailyContentNotifications();
    }
  }

  /// Initialize service.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load timezones
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      debugPrint('🕐 Timezone initialized: ${tz.local.name}');

      // Initialize notification plugin
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '🔔 Daily content notification tapped: ${response.payload}',
          );
        },
      );

      // Create Android notification channel
      final languageService = LanguageService();
      await languageService.load();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Notification permission
        final hasPermission =
            await androidImplementation.areNotificationsEnabled() ?? false;
        debugPrint('📱 Daily content notification permission: $hasPermission');

        if (!hasPermission) {
          debugPrint('⚠️ Daily content permission not granted, requesting...');
          await androidImplementation.requestNotificationsPermission();
        }

        // Exact alarm permission
        final canScheduleExact =
            await androidImplementation.canScheduleExactNotifications() ??
            false;
        debugPrint('⏰ Exact alarm permission: $canScheduleExact');

        if (!canScheduleExact) {
          debugPrint('⚠️ Exact alarm permission not granted, requesting...');
          await androidImplementation.requestExactAlarmsPermission();
        }

        // Get sound ID
        final soundId = await getDailyContentNotificationSound();

        // Delete old channels (for sound change)
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
          debugPrint('🗑️ Old daily content channels deleted');
        } catch (e) {
          debugPrint('⚠️ Channel delete error (may be normal): $e');
        }

        // Create daily content channel
        final channelName =
            languageService['daily_content_channel_name'] ?? 'Daily Content';
        final channelDescription =
            languageService['daily_content_channel_desc'] ??
            'Daily verse, hadith, and dua notifications';
        final channel = AndroidNotificationChannel(
          'daily_content_channel_v4',
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundId),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        debugPrint('✅ Daily content channel created (sound ID: $soundId)');
      }

      _initialized = true;
      debugPrint('✅ Daily content notification service started');
    } catch (e) {
      debugPrint('❌ Daily content notification service failed: $e');
    }
  }

  /// Schedule daily alarms.
  static Future<void> scheduleDailyContentNotifications() async {
    debugPrint('📱 Scheduling daily content alarms...');

    if (!_initialized) {
      debugPrint('🔧 Service not initialized yet, initializing...');
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('daily_content_notifications_enabled') ?? true;
    debugPrint('🔍 daily_content_notifications_enabled: $enabled');

    if (!enabled) {
      debugPrint('⏸️ Daily content alarms disabled');
      await cancelAllDailyContentNotifications();
      return;
    }

    try {
      debugPrint('🗑️ Canceling existing daily content alarms...');
      // Mevcut alarmlari iptal et
      await cancelAllDailyContentNotifications();

      // Schedule alarms for 7 days
      final times = await _getDailyContentTimes();
      final verseTimeParts = times['verse']!;
      final hadithTimeParts = times['hadith']!;
      final prayerTimeParts = times['prayer']!;
      final tahajjudTimeParts = times['tahajjud']!;
      final now = tz.TZDateTime.now(tz.local);
      final contentSoundId = await getDailyContentNotificationSound();
      final tahajjudSoundId = await getDailyTahajjudNotificationSound();
      int scheduledCount = 0;

      for (int day = 0; day < 7; day++) {
        final targetDate = now.add(Duration(days: day));

        // Daily verse
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
            soundId: contentSoundId,
          );
          scheduledCount++;
        }

        // Daily hadith
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
            soundId: contentSoundId,
          );
          scheduledCount++;
        }

        // Daily dua
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
            soundId: contentSoundId,
          );
          scheduledCount++;
        }

        // Daily tahajjud reminder
        final tahajjudEnabled = prefs.getBool(_tahajjudEnabledKey) ?? true;
        if (tahajjudEnabled) {
          final tahajjudTime = tz.TZDateTime(
            tz.local,
            targetDate.year,
            targetDate.month,
            targetDate.day,
            tahajjudTimeParts[0],
            tahajjudTimeParts[1],
            0,
          );
          if (tahajjudTime.isAfter(now)) {
            await _scheduleNotification(
              id: tahajjudNotificationId + day * 10,
              title: 'todays_tahajjud',
              body: 'daily_tahajjud_notification_desc',
              scheduledDate: tahajjudTime,
              soundId: tahajjudSoundId,
              // Teheccüd, vakit/erken alarmları gibi zamanında uyandırmalı;
              // Doze'dan tamamen muaf olan setAlarmClock ile zamanlanır (bkz.
              // AlarmReceiver.kt). Ayet/hadis/dua bilgilendirme amaçlı
              // olduğundan onlarda daha az öncelikli setExactAndAllowWhileIdle
              // yeterli.
              alarmClock: true,
            );
            scheduledCount++;
          }
        } else {
          // Tahajjud devre disi - mevcut alarmlari iptal et
          await AlarmService.cancelDailyContentAlarm(
            tahajjudNotificationId + day * 10,
          );
        }
      }

      debugPrint('✅ Daily content alarms scheduled ($scheduledCount total):');
      debugPrint(
        '   📖 Verse time: ${times['verse']![0].toString().padLeft(2, '0')}:${times['verse']![1].toString().padLeft(2, '0')}',
      );
      debugPrint(
        '   📿 Hadith time: ${times['hadith']![0].toString().padLeft(2, '0')}:${times['hadith']![1].toString().padLeft(2, '0')}',
      );
      debugPrint(
        '   🤲 Dua time: ${times['prayer']![0].toString().padLeft(2, '0')}:${times['prayer']![1].toString().padLeft(2, '0')}',
      );
      debugPrint(
        '   🌙 Tahajjud time: ${times['tahajjud']![0].toString().padLeft(2, '0')}:${times['tahajjud']![1].toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('❌ Daily content alarm scheduling failed: $e');
    }
  }

  static Future<Map<String, List<int>>> _getDailyContentTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final verse = prefs.getString(_verseTimeKey) ?? _defaultVerseTime;
    final hadith = prefs.getString(_hadithTimeKey) ?? _defaultHadithTime;
    final prayer = prefs.getString(_prayerTimeKey) ?? _defaultPrayerTime;
    final tahajjud = prefs.getString(_tahajjudTimeKey) ?? _defaultTahajjudTime;

    return {
      'verse': _parseTimeParts(verse, _defaultVerseTime),
      'hadith': _parseTimeParts(hadith, _defaultHadithTime),
      'prayer': _parseTimeParts(prayer, _defaultPrayerTime),
      'tahajjud': _parseTimeParts(tahajjud, _defaultTahajjudTime),
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

  /// Schedule a notification (7-day system).
  static Future<void> _scheduleNotification({
    required int id,
    required String title, // Localization key
    required String body, // Localization key
    required tz.TZDateTime scheduledDate,
    required String soundId,
    bool alarmClock = false,
  }) async {
    // Load translations
    final languageService = LanguageService();
    await languageService.load();

    final titleText = languageService[title] ?? title;

    // Calculate content by month and day.
    String bodyText = '';

    // İçerik, ana ekrandaki "Günün İçeriği" kartıyla aynı kaynaktan gelir
    // (GunlukHadisDuaService). Sonuç tarih anahtarlı önbelleğe yazıldığı için
    // o gün geldiğinde kart ile bildirim birebir aynı içeriği gösterir.
    final icerikTarihi = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    if (title == 'todays_verse') {
      // Kur'an verisi arka planda yüklendiği için burada hazır olmasını
      // bekle; aksi halde bildirim yerel yedek havuzdan ayet alır ve
      // ana ekrandaki kartla farklı içerik gösterir.
      await KuranVeriService.yukle();
      final ayet = GunlukHadisDuaService.gununAyeti(icerikTarihi);
      final text = ayet['text'] ?? '';
      if (text.isNotEmpty) {
        bodyText = '$text\n📖 ${ayet['source'] ?? ''}';
      }
    } else if (title == 'todays_hadith') {
      final hadis = await GunlukHadisDuaService.gununHadisi(icerikTarihi);
      final text = hadis['text'] ?? '';
      if (text.isNotEmpty) {
        bodyText = '$text\n📿 ${hadis['source'] ?? ''}';
      }
    } else if (title == 'todays_dua') {
      final dua = await GunlukHadisDuaService.gununDuasi(icerikTarihi);
      final text = dua['text'] ?? '';
      if (text.isNotEmpty) {
        bodyText = '$text\n🤲 ${dua['source'] ?? ''}';
      }
    } else {
      bodyText = languageService[body] ?? body;
    }

    debugPrint('🔊 Daily content sound ID: $soundId');

    // Bildirime tıklanınca hangi içeriğin açılacağını native tarafa taşımak
    // için 'title' çeviri anahtarından sabit bir tür kimliği türetilir.
    const contentTypes = {
      'todays_verse': 'verse',
      'todays_hadith': 'hadith',
      'todays_dua': 'prayer',
      'todays_tahajjud': 'tahajjud',
    };

    // Schedule via AlarmManager
    final success = await AlarmService.scheduleDailyContentAlarm(
      notificationId: id,
      title: titleText,
      body: bodyText,
      triggerAtMillis: scheduledDate.millisecondsSinceEpoch,
      soundFile: soundId,
      alarmClock: alarmClock,
      contentType: contentTypes[title] ?? '',
    );

    if (success) {
      debugPrint(
        '📅 Daily content scheduled: $titleText - ${scheduledDate.day}/${scheduledDate.month} ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')} (ID: $id)',
      );
    } else {
      debugPrint('❌ Daily content scheduling failed: $titleText (ID: $id)');
    }
  }

  /// Cancel all daily content alarms.
  static Future<void> cancelAllDailyContentNotifications() async {
    // Cancel AlarmManager scheduled notifications
    await AlarmService.cancelAllDailyContentAlarms();
    debugPrint('🚫 Daily content alarms canceled (AlarmManager)');
  }

  /// Enable/disable daily content alarms.
  static Future<void> setDailyContentNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_content_notifications_enabled', enabled);
    if (enabled) {
      await scheduleDailyContentNotifications();
    } else {
      await cancelAllDailyContentNotifications();
    }
  }

  /// Send a test notification.
  static Future<void> sendTestNotification(String type) async {
    if (!_initialized) {
      await initialize();
    }

    final languageService = LanguageService();
    await languageService.load();

    String title;
    String body;
    int id;

    // Calculate today's content by month/day rotation.
    final now = DateTime.now();

    switch (type) {
      case 'verse':
        title = languageService['todays_verse'] ?? '';
        await KuranVeriService.yukle();
        final ayet = GunlukHadisDuaService.gununAyeti(now);
        final ayetMetni = ayet['text'] ?? '';
        body = ayetMetni.isEmpty
            ? ''
            : '$ayetMetni\n📖 ${ayet['source'] ?? ''}';
        id = 9000;
        break;
      case 'hadith':
        title = languageService['todays_hadith'] ?? '';
        final hadis = await GunlukHadisDuaService.gununHadisi(now);
        final hadisMetni = hadis['text'] ?? '';
        body = hadisMetni.isEmpty
            ? ''
            : '$hadisMetni\n📿 ${hadis['source'] ?? ''}';
        id = 9001;
        break;
      case 'prayer':
        title = languageService['todays_dua'] ?? '';
        final dua = await GunlukHadisDuaService.gununDuasi(now);
        final duaMetni = dua['text'] ?? '';
        body = duaMetni.isEmpty ? '' : '$duaMetni\n🤲 ${dua['source'] ?? ''}';
        id = 9002;
        break;
      case 'tahajjud':
        title = languageService['todays_tahajjud'] ?? '';
        body = languageService['daily_tahajjud_notification_desc'] ?? '';
        id = 9003;
        break;
      default:
        return;
    }

    final soundId = type == 'tahajjud'
        ? await getDailyTahajjudNotificationSound()
        : await getDailyContentNotificationSound();
    final channelName =
        languageService['daily_content_channel_name'] ?? 'Daily Content';
    final channelDescription =
        languageService['daily_content_channel_desc'] ??
        'Daily verse, hadith, and dua notifications';
    final channelTicker =
        languageService['daily_content_channel_ticker'] ?? 'Daily content';
    final appName = languageService['app_name'] ?? 'Huzura Davet';

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_content_channel_v4',
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundId),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ticker: channelTicker,
      // BigText style - show full content
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: appName,
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

    debugPrint('🔔 Test notification sent: $title');
  }
}
