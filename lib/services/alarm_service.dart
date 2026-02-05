import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Android alarm sistemi için Flutter servis sınıfı
/// Bildirim ayarları ile senkronize çalışır
class AlarmService {
  static const _channel = MethodChannel('huzur_vakti/alarms');

  /// Belirli bir vakit için alarm kurar
  /// [prayerName] - Vakit adı (Örn: "Sabah", "Öğle")
  /// [triggerAtMillis] - Alarmın tetikleneceği zaman (Unix timestamp ms)
  /// [soundPath] - Ses dosyası yolu (null ise varsayılan ses kullanılır)
  /// [useVibration] - Titreşim kullanılsın mı
  /// [alarmId] - Benzersiz alarm ID'si (varsayılan: prayerName.hashCode)
  /// [isEarly] - Erken bildirim mi (vaktinden önce)
  /// [earlyMinutes] - Erken bildirim için kaç dakika önce
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
        '🔔 [ALARM SCHEDULE] prayerName=$prayerName, triggerTime=$triggerTime, soundPath=$soundPath, alarmId=${alarmId ?? prayerName.hashCode}, isEarly=$isEarly, earlyMinutes=$earlyMinutes',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Alarm zamanı geçmiş, atlanıyor');
        return false;
      }

      // Ses dosyasını normalize et (uzantısız ve küçük harf)
      String? normalizedSoundPath = soundPath;
      if (soundPath != null && soundPath.isNotEmpty) {
        normalizedSoundPath = soundPath.toLowerCase();
        if (normalizedSoundPath.endsWith('.mp3')) {
          normalizedSoundPath = normalizedSoundPath.substring(0, normalizedSoundPath.length - 4);
        }
        normalizedSoundPath = normalizedSoundPath.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      }
      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'prayerName': prayerName,
        'triggerAtMillis': triggerAtMillis,
        'soundPath': normalizedSoundPath,
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
      debugPrint('❌ Alarm kurma hatası: $e');
      return false;
    }
  }

  /// Belirli bir alarmı iptal eder
  static Future<bool> cancelAlarm(int alarmId) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAlarm', {
        'alarmId': alarmId,
      });
      return result ?? false;
    } catch (e) {
      print('Alarm iptal hatası: $e');
      return false;
    }
  }

  /// Tüm alarmları iptal eder
  static Future<bool> cancelAllAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAllAlarms');
      return result ?? false;
    } catch (e) {
      print('Tüm alarmları iptal hatası: $e');
      return false;
    }
  }

  /// Alarm çalıyor mu kontrol eder
  static Future<bool> isAlarmPlaying() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } catch (e) {
      print('Alarm kontrol hatası: $e');
      return false;
    }
  }

  /// Çalan alarmı durdurur
  static Future<bool> stopAlarm() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopAlarm');
      return result ?? false;
    } catch (e) {
      print('Alarm durdurma hatası: $e');
      return false;
    }
  }

  /// Vakit ID'sinden benzersiz alarm ID'si oluşturur
  /// Aynı günde farklı vakitler için farklı ID'ler üretir
  static int generateAlarmId(String prayerKey, DateTime date) {
    // prayerKey: "imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"
    // Tarih ve vakit bazında benzersiz ID
    final dateStr = '${date.year}${date.month}${date.day}';
    return '${dateStr}_$prayerKey'.hashCode.abs();
  }

  /// Özel gün/gece bildirimi için alarm kur
  /// Bu bildirimler uygulama kapalı olsa bile çalmalı
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
        '🕌 [ÖZEL GÜN ALARM] title=$title, triggerTime=$triggerTime, alarmId=$alarmId',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Özel gün alarm zamanı geçmiş, atlanıyor');
        return false;
      }

      final result = await _channel.invokeMethod<bool>('scheduleOzelGunAlarm', {
        'title': title,
        'body': body,
        'triggerAtMillis': triggerAtMillis,
        'alarmId': alarmId,
      });
      debugPrint('✅ [ÖZEL GÜN ALARM RESULT] title=$title, result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Özel gün alarm kurma hatası: $e');
      return false;
    }
  }

  /// Günlük içerik bildirimi için alarm kur (AlarmManager kullanır)
  /// Bu bildirimler uygulama kapalı olsa bile çalmalı
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

      // Ses dosyasını normalize et
      String normalizedSoundFile = soundFile.toLowerCase();
      if (normalizedSoundFile.endsWith('.mp3')) {
        normalizedSoundFile = normalizedSoundFile.substring(0, normalizedSoundFile.length - 4);
      }
      normalizedSoundFile = normalizedSoundFile.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      if (normalizedSoundFile.isEmpty) normalizedSoundFile = 'ding_dong';

      debugPrint(
        '📅 [GÜNLÜK İÇERİK ALARM] title=$title, triggerTime=$triggerTime, notificationId=$notificationId, soundFile=$soundFile -> $normalizedSoundFile',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Günlük içerik alarm zamanı geçmiş, atlanıyor');
        return false;
      }

      final result = await _channel
          .invokeMethod<bool>('scheduleDailyContentAlarm', {
            'notificationId': notificationId,
            'title': title,
            'body': body,
            'triggerAtMillis': triggerAtMillis,
            'soundFile': normalizedSoundFile,
          });
      debugPrint('✅ [GÜNLÜK İÇERİK ALARM RESULT] title=$title, result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Günlük içerik alarm kurma hatası: $e');
      return false;
    }
  }

  /// Günlük içerik alarmını iptal et
  static Future<bool> cancelDailyContentAlarm(int notificationId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'cancelDailyContentAlarm',
        {'notificationId': notificationId},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Günlük içerik alarm iptal hatası: $e');
      return false;
    }
  }

  /// Tüm günlük içerik alarmlarını iptal et
  static Future<bool> cancelAllDailyContentAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'cancelAllDailyContentAlarms',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Tüm günlük içerik alarmları iptal hatası: $e');
      return false;
    }
  }

  /// TEST: 5 saniye sonra çalacak test alarmı
  /// Bu fonksiyon alarm sisteminin çalışıp çalışmadığını test etmek için
  static Future<bool> testAlarm() async {
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 5));
      debugPrint('🧪 TEST ALARM: 5 saniye sonra çalacak - $testTime');

      final result = await scheduleAlarm(
        prayerName: 'Test Alarmı',
        triggerAtMillis: testTime.millisecondsSinceEpoch,
        soundPath: 'ding_dong.mp3',
        useVibration: true,
        alarmId: 99999, // Test için sabit ID
      );

      debugPrint('🧪 TEST ALARM sonucu: $result');
      return result;
    } catch (e) {
      debugPrint('❌ TEST ALARM hatası: $e');
      return false;
    }
  }
}
