import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

  /// Flutter service for Android alarms.
  /// Syncs with notification settings.
class AlarmService {
  static const _channel = MethodChannel('huzur_vakti/alarms');

  /// Schedule an alarm for a prayer.
  /// [prayerName] - Prayer name
  /// [triggerAtMillis] - Trigger time (Unix ms)
  /// [soundPath] - Sound ID (Android raw resource name)
  /// [useVibration] - Use vibration
  /// [alarmId] - Unique alarm ID (default: prayerName.hashCode)
  /// [isEarly] - Early reminder
  /// [earlyMinutes] - Minutes before
  static Future<bool> scheduleAlarm({
    required String prayerName,
    required int triggerAtMillis,
    String? soundPath,
    bool useVibration = true,
    int? alarmId,
    bool isEarly = false,
    int earlyMinutes = 0,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final triggerTime = DateTime.fromMillisecondsSinceEpoch(triggerAtMillis);

      debugPrint(
        '🔔 [ALARM SCHEDULE] prayerName=$prayerName, triggerTime=$triggerTime, soundId=$soundPath, alarmId=${alarmId ?? prayerName.hashCode}, isEarly=$isEarly, earlyMinutes=$earlyMinutes',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Alarm time already passed, skipping');
        return false;
      }

      // Sound ID is already normalized
      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'prayerName': prayerName,
        'triggerAtMillis': triggerAtMillis,
        'soundPath': soundPath, // Direkt ses ID'si
        'useVibration': useVibration,
        'alarmId': alarmId ?? prayerName.hashCode,
        'isEarly': isEarly,
        'earlyMinutes': earlyMinutes,
      });
      debugPrint(
        '✅ [ALARM SCHEDULE RESULT] prayerName=$prayerName, result=$result',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Alarm scheduling error: $e');
      return false;
    }
  }

  /// Cancel a specific alarm.
  static Future<bool> cancelAlarm(int alarmId) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAlarm', {
        'alarmId': alarmId,
      });
      return result ?? false;
    } catch (e) {
      print('Alarm cancel error: $e');
      return false;
    }
  }

  /// Cancel all alarms.
  static Future<bool> cancelAllAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAllAlarms');
      return result ?? false;
    } catch (e) {
      print('Cancel all alarms error: $e');
      return false;
    }
  }

  /// Check whether an alarm is playing.
  static Future<bool> isAlarmPlaying() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } catch (e) {
      print('Alarm status error: $e');
      return false;
    }
  }

  /// Stop the active alarm.
  static Future<bool> stopAlarm() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopAlarm');
      return result ?? false;
    } catch (e) {
      print('Stop alarm error: $e');
      return false;
    }
  }

  /// Generate a unique alarm ID by prayer and date.
  static int generateAlarmId(String prayerKey, DateTime date) {
    // prayerKey: "imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"
    final dateStr = '${date.year}${date.month}${date.day}';
    return '${dateStr}_$prayerKey'.hashCode.abs();
  }

  /// Schedule a special day/night alarm.
  static Future<bool> scheduleOzelGunAlarm({
    required String title,
    required String body,
    required int triggerAtMillis,
    required int alarmId,
  }) async {
    try {
      final triggerTime = DateTime.fromMillisecondsSinceEpoch(triggerAtMillis);
      final now = DateTime.now().millisecondsSinceEpoch;

      debugPrint(
        '🕌 [SPECIAL DAY ALARM] title=$title, triggerTime=$triggerTime, alarmId=$alarmId',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Special day alarm time passed, skipping');
        return false;
      }

      final result = await _channel.invokeMethod<bool>('scheduleOzelGunAlarm', {
        'title': title,
        'body': body,
        'triggerAtMillis': triggerAtMillis,
        'alarmId': alarmId,
      });
      debugPrint('✅ [SPECIAL DAY ALARM RESULT] title=$title, result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Special day alarm scheduling error: $e');
      return false;
    }
  }

  /// Schedule a daily content alarm (AlarmManager).
  static Future<bool> scheduleDailyContentAlarm({
    required int notificationId,
    required String title,
    required String body,
    required int triggerAtMillis,
    required String soundFile,
  }) async {
    try {
      final triggerTime = DateTime.fromMillisecondsSinceEpoch(triggerAtMillis);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Sound ID is already normalized
      debugPrint(
        '📅 [DAILY CONTENT ALARM] title=$title, triggerTime=$triggerTime, notificationId=$notificationId, soundId=$soundFile',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Daily content alarm time passed, skipping');
        return false;
      }

      final result = await _channel.invokeMethod<bool>(
        'scheduleDailyContentAlarm',
        {
          'notificationId': notificationId,
          'title': title,
          'body': body,
          'triggerAtMillis': triggerAtMillis,
          'soundFile': soundFile, // Raw sound ID
        },
      );
      debugPrint('✅ [DAILY CONTENT ALARM RESULT] title=$title, result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Daily content alarm scheduling error: $e');
      return false;
    }
  }

  /// Cancel a daily content alarm.
  static Future<bool> cancelDailyContentAlarm(int notificationId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'cancelDailyContentAlarm',
        {'notificationId': notificationId},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Daily content alarm cancel error: $e');
      return false;
    }
  }

  /// Cancel all daily content alarms.
  static Future<bool> cancelAllDailyContentAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'cancelAllDailyContentAlarms',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Cancel all daily content alarms error: $e');
      return false;
    }
  }

  /// TEST: Trigger a test alarm after 5 seconds.
  static Future<bool> testAlarm() async {
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 5));
      debugPrint('🧪 TEST ALARM: will fire in 5 seconds - $testTime');

      final result = await scheduleAlarm(
        prayerName: 'Test Alarm',
        triggerAtMillis: testTime.millisecondsSinceEpoch,
        soundPath: 'ding_dong.mp3',
        useVibration: true,
        alarmId: 99999, // Fixed ID for test
      );

      debugPrint('🧪 TEST ALARM result: $result');
      return result;
    } catch (e) {
      debugPrint('❌ TEST ALARM error: $e');
      return false;
    }
  }
}
