import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'alarm_service.dart';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'language_service.dart';

/// Early reminder alarm service.
/// Schedules independent early reminder alarms for each prayer time.
/// Manages sound and duration settings.
class EarlyReminderService {
  static bool _initialized = false;

  // Prayer time names (API compatible)
  static const List<String> _vakitler = [
    'Imsak',
    'Gunes',
    'Ogle',
    'Ikindi',
    'Aksam',
    'Yatsi',
  ];

  // Default early reminder durations (minutes)
  static const Map<String, int> varsayilanErkenSureler = {
    'imsak': 15,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Default sound ID
  static const String varsayilanSes = 'best';

  /// Initialize service.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('✅ Early reminder service initialized');
  }

  // =============================================
  // SETTINGS
  // =============================================

  /// Get early reminder duration (minutes).
  static Future<int> getErkenSure(String vakitKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('erken_$vakitKey') ??
        (varsayilanErkenSureler[vakitKey] ?? 15);
  }

  /// Set early reminder duration (minutes).
  static Future<void> setErkenSure(String vakitKey, int dakika) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('erken_$vakitKey', dakika);
    debugPrint('💾 Early duration saved: $vakitKey = $dakika');
  }

  /// Get early reminder sound (sound ID).
  static Future<String> getErkenSes(String vakitKey) async {
    final prefs = await SharedPreferences.getInstance();
    final ses = prefs.getString('erken_bildirim_sesi_$vakitKey');
    if (ses != null && ses.isNotEmpty) return ses;
    // If no saved sound, use on-time sound
    final vaktindeSes = prefs.getString('bildirim_sesi_$vakitKey');
    return vaktindeSes ?? varsayilanSes;
  }

  /// Set early reminder sound (sound ID).
  static Future<void> setErkenSes(String vakitKey, String sesId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('erken_bildirim_sesi_$vakitKey', sesId);
    debugPrint('💾 Early sound saved: $vakitKey = $sesId');
  }

  /// Normalize sound file name to Android raw resource name
  /// e.g. "best.mp3" -> "best", "aksam_ezani.mp3" -> "aksam_ezani"
  static String normalizeSoundName(String soundFile) {
    if (soundFile.isEmpty) return 'best';
    String name = soundFile.toLowerCase();
    // If path exists, take last segment
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    // Remove .mp3 extension
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }
    // Remove invalid characters
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    // Collapse multiple underscores
    name = name.replaceAll(RegExp(r'_+'), '_');
    // Trim leading/trailing underscores
    name = name.replaceAll(RegExp(r'^_+|_+$'), '');
    if (name.isEmpty) return 'best';
    return name;
  }

  // =============================================
  // ALARM SCHEDULING
  // =============================================

  /// Schedule early reminder alarms for all times (7 days)
  static Future<int> scheduleAllEarlyReminders() async {
    try {
      if (!_initialized) await initialize();

      final languageService = LanguageService();
      final minuteShort = languageService['minute_short'] ?? 'min';

      debugPrint('⏰ ===== EARLY REMINDER SCHEDULING START =====');

      // Cancel existing early alarms
      await cancelAllEarlyReminders();

      // Get location ID
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        debugPrint('❌ Location not selected. Early reminders cannot be scheduled.');
        debugPrint('⚠️ Please select a location from the home screen.');
        debugPrint('==========================================');
        return 0;
      }
      debugPrint('📍 Location ID: $ilceId');

      // Fetch 7-day prayer data
      final now = DateTime.now();
      debugPrint('🕐 Current time: $now');

      final aylikVakitler = await DiyanetApiService.getAylikVakitler(
        ilceId,
        now.year,
        now.month,
      );
      debugPrint('📅 Prayer count this month: ${aylikVakitler.length}');

      // Next month may be needed
      List<Map<String, dynamic>> sonrakiAyVakitler = [];
      if (now.day > 24) {
        final sonrakiAy = now.month == 12 ? 1 : now.month + 1;
        final sonrakiYil = now.month == 12 ? now.year + 1 : now.year;
        sonrakiAyVakitler = await DiyanetApiService.getAylikVakitler(
          ilceId,
          sonrakiYil,
          sonrakiAy,
        );
        debugPrint('📅 Prayer count next month: ${sonrakiAyVakitler.length}');
      }

      final tumVakitler = [...aylikVakitler, ...sonrakiAyVakitler];
      if (tumVakitler.isEmpty) {
        debugPrint('❌ Prayer data could not be retrieved.');
        debugPrint('⚠️ Check your internet connection.');
        debugPrint('==========================================');
        return 0;
      }
      debugPrint('📊 Total prayer data days: ${tumVakitler.length}');

      final prefs = await SharedPreferences.getInstance();
      int alarmCount = 0;
      int skippedCount = 0;

      // Loop for 7 days
      for (int gun = 0; gun < 7; gun++) {
        final hedefTarih = now.add(Duration(days: gun));
        final hedefTarihStr =
            '${hedefTarih.day.toString().padLeft(2, '0')}.${hedefTarih.month.toString().padLeft(2, '0')}.${hedefTarih.year}';

        debugPrint('\\n📆 Day $gun: $hedefTarihStr');

        // Find prayer data for the day
        final gunVakitler = tumVakitler.firstWhere(
          (v) => v['MiladiTarihKisa'] == hedefTarihStr,
          orElse: () => <String, dynamic>{},
        );

        if (gunVakitler.isEmpty) {
          debugPrint('   ⚠️ No prayer data for this day');
          continue;
        }

        for (int i = 0; i < _vakitler.length; i++) {
          final vakitKey = _vakitler[i];
          final vakitKeyLower = vakitKey.toLowerCase();

          // Skip early reminder if main notification is off
          final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;
          if (!bildirimAcik) {
            debugPrint(
              '   ⏭️ $vakitKey main notification off, skipping early reminder',
            );
            skippedCount++;
            continue;
          }

              // Early reminder duration
          final erkenDakika =
              prefs.getInt('erken_$vakitKeyLower') ??
              (varsayilanErkenSureler[vakitKeyLower] ?? 15);

          // Early minutes 0 means disabled
          if (erkenDakika <= 0) {
            debugPrint('   ⏭️ $vakitKey early reminder off (0 min)');
            skippedCount++;
            continue;
          }

          // Get prayer time
          final vakitSaati = gunVakitler[vakitKey]?.toString();
          if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
            debugPrint('   ⚠️ $vakitKey time not found');
            continue;
          }

          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;
          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // Save prayer time for BootReceiver
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          // Exact prayer time
          final vakitZamani = DateTime(
            hedefTarih.year,
            hedefTarih.month,
            hedefTarih.day,
            saat,
            dakika,
          );

          // Early alarm time
          final erkenAlarmZamani = vakitZamani.subtract(
            Duration(minutes: erkenDakika),
          );

          if (!erkenAlarmZamani.isAfter(now)) {
            debugPrint(
              '   ⏭️ $vakitKey early alarm time passed ($erkenAlarmZamani)',
            );
            skippedCount++;
            continue;
          }

          // Get early alarm sound ID
          final erkenSesId =
              prefs.getString('erken_bildirim_sesi_$vakitKeyLower') ??
              prefs.getString('bildirim_sesi_$vakitKeyLower') ??
              varsayilanSes;

          // Create unique alarm ID
          final erkenAlarmId = AlarmService.generateAlarmId(
            '${vakitKeyLower}_erken',
            erkenAlarmZamani,
          );

          debugPrint(
            '   ⏰ $vakitKey early alarm: $erkenAlarmZamani ($erkenDakika min), sound: $erkenSesId, ID: $erkenAlarmId',
          );

          final prayerLabel = _getPrayerLabel(languageService, vakitKey);
          final prayerName = '$prayerLabel ($erkenDakika $minuteShort)';

          // Schedule alarm - send sound ID directly
          final success = await AlarmService.scheduleAlarm(
            prayerName: prayerName,
            triggerAtMillis: erkenAlarmZamani.millisecondsSinceEpoch,
            soundPath: erkenSesId, // Ses ID'si
            useVibration: true,
            alarmId: erkenAlarmId,
            isEarly: true,
            earlyMinutes: erkenDakika,
          );

          if (success) {
            alarmCount++;
            debugPrint('      ✅ Early alarm scheduled');
          } else {
            debugPrint('      ❌ Early alarm scheduling failed');
            skippedCount++;
          }
        }
      }

      debugPrint('\\n⏰ ===== EARLY REMINDER SCHEDULING END =====');
      debugPrint('✅ Alarms scheduled: $alarmCount');
      debugPrint('⏭️ Skipped/failed: $skippedCount');
      debugPrint('==========================================\\n');
      return alarmCount;
    } catch (e, stackTrace) {
      debugPrint('❌ EARLY REMINDER SCHEDULING ERROR: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      debugPrint('==========================================');
      return 0;
    }
  }

  /// Cancel all early reminder alarms.
  static Future<void> cancelAllEarlyReminders() async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      for (final vakitKey in _vakitler) {
        final vakitKeyLower = vakitKey.toLowerCase();
        final erkenAlarmId = AlarmService.generateAlarmId(
          '${vakitKeyLower}_erken',
          hedefTarih,
        );
        await AlarmService.cancelAlarm(erkenAlarmId);
      }
    }
    debugPrint('🗑️ All early reminder alarms canceled');
  }

  /// Cancel early reminder alarm for a specific prayer.
  static Future<void> cancelEarlyReminder(String vakitKeyLower) async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      final erkenAlarmId = AlarmService.generateAlarmId(
        '${vakitKeyLower}_erken',
        hedefTarih,
      );
      await AlarmService.cancelAlarm(erkenAlarmId);
    }
    debugPrint('🗑️ $vakitKeyLower early reminder alarm canceled');
  }

  /// Save settings and reschedule alarms.
  /// Returns: number of scheduled alarms.
  static Future<int> saveAndReschedule({
    required Map<String, int> erkenSureler,
    required Map<String, String> erkenSesler,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    debugPrint('💾 Saving early reminder settings...');
    for (final entry in erkenSureler.entries) {
      await prefs.setInt('erken_${entry.key}', entry.value);
      debugPrint('   - ${entry.key}: ${entry.value} minutes');
    }

    for (final entry in erkenSesler.entries) {
      await prefs.setString('erken_bildirim_sesi_${entry.key}', entry.value);
    }

    debugPrint('💾 Early reminder settings saved');

    // Reschedule alarms and return scheduled count
    final alarmCount = await scheduleAllEarlyReminders();
    debugPrint('🔔 Total early reminders scheduled: $alarmCount');
    return alarmCount;
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
