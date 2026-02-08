import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'alarm_service.dart';
import 'early_reminder_service.dart';
import 'language_service.dart';

/// Scheduled alarm service - schedules prayer alarms even when app is closed.
/// NOTE: Early reminders are managed by EarlyReminderService.
class ScheduledNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _dailyScheduleTimer;
  static DateTime? _lastScheduleDate;

  // Prayer time names
  static const List<String> _vakitler = [
    'Imsak',
    'Gunes',
    'Ogle',
    'Ikindi',
    'Aksam',
    'Yatsi',
  ];

  /// Initialize service.
  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(settings: initializationSettings);

    // Android 13+ notification permission check
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      final hasPermission =
          await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Notification permission status: $hasPermission');

      if (!hasPermission) {
        debugPrint('⚠️ Notification permission missing. Requesting...');
        final granted =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        debugPrint('📱 Notification permission result: $granted');

        if (!granted) {
          debugPrint('❌ Notification permission denied. Notifications will not work.');
        }
      }

      // Exact alarm permission check (Android 12+)
      final canScheduleExact =
          await androidImplementation.canScheduleExactNotifications() ?? false;
      debugPrint('⏰ Exact alarm permission: $canScheduleExact');

      if (!canScheduleExact) {
        debugPrint('⚠️ Exact alarm permission missing. Requesting...');
        final granted =
            await androidImplementation.requestExactAlarmsPermission() ?? false;
        debugPrint('⏰ Exact alarm permission result: $granted');
      }
    }

    _initialized = true;
    debugPrint('✅ Scheduled notification service initialized');

    // Start daily scheduling check
    _startDailyScheduleCheck();
  }

  /// Start a timer that checks daily alarms.
  /// With 7-day scheduling, re-schedule only when needed.
  static void _startDailyScheduleCheck() {
    _dailyScheduleTimer?.cancel();
    // Check every 30 minutes (battery friendly)
    _dailyScheduleTimer = Timer.periodic(const Duration(minutes: 30), (
      _,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // First-time scheduling
      if (_lastScheduleDate == null) {
        debugPrint('📅 Performing initial scheduling...');
        await scheduleAllPrayerNotifications();
        _lastScheduleDate = today;
        return;
      }

      // Re-schedule on day 6 to maintain at least 1 day scheduled
      final daysSinceLastSchedule = today.difference(_lastScheduleDate!).inDays;
      if (daysSinceLastSchedule >= 6) {
        debugPrint('📅 6 days passed, rescheduling notifications...');
        await scheduleAllPrayerNotifications();
        _lastScheduleDate = today;
      }
    });
  }

  /// Schedule all prayer alarms (7 days - 1 week)
  /// Alarms work even if the app is closed for a few days.
  static Future<void> scheduleAllPrayerNotifications() async {
    try {
      // Schedule for 7 days (1 week)
      const int zamanlamaSuresi = 7;
      debugPrint(
        '🔔 Scheduling $zamanlamaSuresi days of prayer notifications...',
      );

      // Cancel existing prayer notifications/alarms first
      await cancelAllNotifications();

      // Get location ID
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        debugPrint('⚠️ CRITICAL: Location not selected, cannot schedule notifications.');
        debugPrint('📍 User must select a location (city/district).');
        return;
      }

      // Get monthly data for 7-day schedule
      final now = DateTime.now();
      final aylikVakitler = await DiyanetApiService.getAylikVakitler(
        ilceId,
        now.year,
        now.month,
      );

      // Next month may be needed (end of month or 7 days)
      List<Map<String, dynamic>> sonrakiAyVakitler = [];
      if (now.day > 24) {
        // Start early for 7 days
        final sonrakiAy = now.month == 12 ? 1 : now.month + 1;
        final sonrakiYil = now.month == 12 ? now.year + 1 : now.year;
        sonrakiAyVakitler = await DiyanetApiService.getAylikVakitler(
          ilceId,
          sonrakiYil,
          sonrakiAy,
        );
      }

      // Merge all times
      final tumVakitler = [...aylikVakitler, ...sonrakiAyVakitler];

      if (tumVakitler.isEmpty) {
        debugPrint('⚠️ Prayer time data not available');
        return;
      }

      debugPrint('📋 Retrieved ${tumVakitler.length} days of data');

      // Load user settings
      final prefs = await SharedPreferences.getInstance();
      final languageService = LanguageService();
      await languageService.load();
      int alarmCount = 0;

      // Loop for 7 days (1 week)
      for (int gun = 0; gun < zamanlamaSuresi; gun++) {
        final hedefTarih = now.add(Duration(days: gun));
        final hedefTarihStr =
            '${hedefTarih.day.toString().padLeft(2, '0')}.${hedefTarih.month.toString().padLeft(2, '0')}.${hedefTarih.year}';

        // Find times for the day
        final gunVakitler = tumVakitler.firstWhere(
          (v) => v['MiladiTarihKisa'] == hedefTarihStr,
          orElse: () => <String, dynamic>{},
        );

        if (gunVakitler.isEmpty) {
          debugPrint('⚠️ No times found for $hedefTarihStr');
          continue;
        }

        // Schedule on-time alarm for each prayer
        // NOTE: Early reminders are scheduled separately by EarlyReminderService
        for (int i = 0; i < _vakitler.length; i++) {
          final vakitKey = _vakitler[i];
          final vakitKeyLower = vakitKey.toLowerCase();

          // Main notification switch
          final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;

          // On-time notification flag
          final varsayilanVaktinde =
              (vakitKeyLower == 'ogle' ||
              vakitKeyLower == 'ikindi' ||
              vakitKeyLower == 'aksam' ||
              vakitKeyLower == 'yatsi');
          final vaktindeBildirim =
              prefs.getBool('vaktinde_$vakitKeyLower') ?? varsayilanVaktinde;

          debugPrint(
            '🔍 [$vakitKey] notifications=$bildirimAcik, onTime=$vaktindeBildirim',
          );

          final vakitSaati = gunVakitler[vakitKey]?.toString();
          if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
            continue;
          }

            // On-time alarm sound ID - use raw ID
          final sesId =
              prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'best';

            // Parse time
          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;

          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // Save time for BootReceiver
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          debugPrint(
            '📌 $vakitKey: $saat:$dakika, notifications: $bildirimAcik, onTime: $vaktindeBildirim',
          );

          // Skip if notifications are off
          if (!bildirimAcik) {
            debugPrint('   ⏭️ Notifications off, skipping');
            continue;
          }

          // ON-TIME ALARM - only if on-time notifications enabled
          var alarmZamani = DateTime(
            hedefTarih.year,
            hedefTarih.month,
            hedefTarih.day,
            saat,
            dakika,
          );

          if (vaktindeBildirim && alarmZamani.isAfter(now)) {
            final alarmId = AlarmService.generateAlarmId(
              vakitKeyLower,
              alarmZamani,
            );

            debugPrint('   Alarm ID: $alarmId, sound ID: $sesId');

            final prayerLabel = _getPrayerLabel(languageService, vakitKey);

            final success = await AlarmService.scheduleAlarm(
              prayerName: prayerLabel,
              triggerAtMillis: alarmZamani.millisecondsSinceEpoch,
              soundPath: sesId, // Send raw sound ID
              useVibration: true,
              alarmId: alarmId,
              isEarly: false,
              earlyMinutes: 0,
            );

            if (success) {
              alarmCount++;
              debugPrint('   ✅ On-time alarm scheduled');
            } else {
              debugPrint('   ❌ On-time alarm scheduling failed');
            }
          } else if (!vaktindeBildirim) {
            debugPrint('   ⏭️ On-time notification off, alarm skipped');
          } else {
            debugPrint('   ⏭️ Alarm time passed, skipping');
          }
        }
      }

      // Also schedule early reminders (via EarlyReminderService)
      final erkenAlarmCount =
          await EarlyReminderService.scheduleAllEarlyReminders();
      alarmCount += erkenAlarmCount;

      debugPrint(
        '🔔 $zamanlamaSuresi day scheduling completed: $alarmCount alarms (early: $erkenAlarmCount)',
      );

      // Save last schedule date
      await prefs.setString('last_schedule_date', now.toIso8601String());
      await prefs.setInt('scheduled_days', zamanlamaSuresi);
    } catch (e, stackTrace) {
      debugPrint('❌ Notification scheduling error: $e');
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }

  /// Cancel all prayer time alarms
  /// NOTE: Does not cancel daily content or special day alarms.
  static Future<void> cancelAllNotifications() async {
    await _cancelPrayerAlarms();
    debugPrint('🗑️ Prayer time alarms canceled');
  }

  /// Cancel prayer time alarms (on-time only)
  /// NOTE: Early reminders are canceled by EarlyReminderService.
  static Future<void> _cancelPrayerAlarms() async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      for (final vakitKey in _vakitler) {
        final vakitKeyLower = vakitKey.toLowerCase();
        final alarmId = AlarmService.generateAlarmId(vakitKeyLower, hedefTarih);
        await AlarmService.cancelAlarm(alarmId);
      }
    }
    // Also cancel early reminders
    await EarlyReminderService.cancelAllEarlyReminders();
  }

  /// Schedule next day's alarms (called at midnight)
  static Future<void> scheduleNextDayNotifications() async {
    await scheduleAllPrayerNotifications();
  }

  static String _getPrayerLabel(LanguageService languageService, String key) {
    switch (key) {
      case 'Imsak':
        return languageService['imsak'] ?? key;
      case 'Gunes':
        return languageService['gunes'] ?? key;
      case 'Ogle':
        return languageService['ogle'] ?? key;
      case 'Ikindi':
        return languageService['ikindi'] ?? key;
      case 'Aksam':
        return languageService['aksam'] ?? key;
      case 'Yatsi':
        return languageService['yatsi'] ?? key;
      default:
        return key;
    }
  }
}
