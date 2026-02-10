import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'language_service.dart';
import 'alarm_service.dart';

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

  static const String _verseTimeKey = 'daily_content_verse_time';
  static const String _hadithTimeKey = 'daily_content_hadith_time';
  static const String _prayerTimeKey = 'daily_content_prayer_time';

  // Notification IDs
  static const int verseNotificationId = 1000;
  static const int hadithNotificationId = 1001;
  static const int prayerNotificationId = 1002;

  // Default sound file
  static const String defaultNotificationSound = 'ding_dong';

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

  /// Set daily content alarm times.
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

  /// Update daily content alarm settings.
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
        debugPrint(
          '✅ Daily content channel created (sound ID: $soundId)',
        );
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
      final now = tz.TZDateTime.now(tz.local);
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
          );
          scheduledCount++;
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
    } catch (e) {
      debugPrint('❌ Daily content alarm scheduling failed: $e');
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

  /// Schedule a notification (7-day system).
  static Future<void> _scheduleNotification({
    required int id,
    required String title, // Localization key
    required String body, // Localization key
    required tz.TZDateTime scheduledDate,
  }) async {
    // Load translations
    final languageService = LanguageService();
    await languageService.load();

    final titleText = languageService[title] ?? title;

    // Calculate content by day
    final dayOfYear = scheduledDate
        .difference(DateTime(scheduledDate.year, 1, 1))
        .inDays;
    String bodyText = '';

    if (title == 'todays_verse') {
      // Daily verse from verses list
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
        bodyText = '';
      }
    } else if (title == 'todays_hadith') {
      // Daily hadith from hadiths list
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
        bodyText = '';
      }
    } else if (title == 'todays_dua') {
      // Daily dua from prayers list
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
        bodyText = '';
      }
    } else {
      bodyText = languageService[body] ?? body;
    }

    // Get sound ID
    final soundId = await getDailyContentNotificationSound();

    debugPrint('🔊 Daily content sound ID: $soundId');

    // Schedule via AlarmManager
    final success = await AlarmService.scheduleDailyContentAlarm(
      notificationId: id,
      title: titleText,
      body: bodyText,
      triggerAtMillis: scheduledDate.millisecondsSinceEpoch,
      soundFile: soundId,
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

    // Calculate today's content
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    switch (type) {
      case 'verse':
        title = languageService['todays_verse'] ?? '';
        // Daily verse
        final versesList = languageService['verses'];
        if (versesList is List && versesList.isNotEmpty) {
          final index = dayOfYear % versesList.length;
          final verse = versesList[index];
          if (verse is Map) {
            final text = verse['text']?.toString() ?? '';
            final source = verse['source']?.toString() ?? '';
            body = '$text\n📖 $source';
          } else {
            body = '';
          }
        } else {
          body = '';
        }
        id = 9000;
        break;
      case 'hadith':
        title = languageService['todays_hadith'] ?? '';
        // Daily hadith
        final hadithsList = languageService['hadiths'];
        if (hadithsList is List && hadithsList.isNotEmpty) {
          final index = (dayOfYear + 14) % hadithsList.length;
          final hadith = hadithsList[index];
          if (hadith is Map) {
            final text = hadith['text']?.toString() ?? '';
            final source = hadith['source']?.toString() ?? '';
            body = '$text\n📿 $source';
          } else {
            body = '';
          }
        } else {
          body = '';
        }
        id = 9001;
        break;
      case 'prayer':
        title = languageService['todays_dua'] ?? '';
        // Daily dua
        final prayersList = languageService['prayers'];
        if (prayersList is List && prayersList.isNotEmpty) {
          final index = (dayOfYear + 7) % prayersList.length;
          final prayer = prayersList[index];
          if (prayer is Map) {
            final text = prayer['text']?.toString() ?? '';
            final source = prayer['source']?.toString() ?? '';
            body = '$text\n🤲 $source';
          } else {
            body = '';
          }
        } else {
          body = '';
        }
        id = 9002;
        break;
      default:
        return;
    }

    final soundId = await getDailyContentNotificationSound();
    final channelName =
      languageService['daily_content_channel_name'] ?? 'Daily Content';
    final channelDescription =
      languageService['daily_content_channel_desc'] ??
      'Daily verse, hadith, and dua notifications';
    final channelTicker =
      languageService['daily_content_channel_ticker'] ?? 'Daily content';
    final appName = languageService['app_name'] ?? 'Huzur Vakti';

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
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
